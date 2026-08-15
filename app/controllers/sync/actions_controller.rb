# Batch ingest for the client-side write outbox (see
# app/javascript/lib/outbox.js and sync.js). Each envelope is dispatched
# through Sync::Replay, which is idempotent per client_action_id, so a
# resent batch (a reload mid-drain, a retried POST) is always safe. One
# poison envelope in a batch must not fail the rest — each gets its own
# applied/duplicate/rejected result.
class Sync::ActionsController < ApplicationController
  def create
    results = actions_params.map { |action| replay_one(action) }

    render json: { results: results }
  end

  private

  # A genuinely unexpected error (a bug, a DB constraint we didn't
  # anticipate) must not fail the whole batch — but it also must not be
  # silently relabeled "rejected", which would tell the client to give up
  # retrying an action that may well succeed once the underlying problem is
  # fixed server-side. Report it (so it surfaces the way any other 500
  # would) and mark this one envelope failed_retryable so the client keeps
  # trying it on its own schedule.
  def replay_one(action)
    Sync::Replay.call(
      shop: Current.shop,
      device: Current.device,
      user: Current.user,
      client_action_id: action.fetch(:client_action_id),
      kind: action.fetch(:kind),
      payload: action.fetch(:payload, {}).to_h
    )
  rescue => e
    Rails.error.report(e, handled: true, context: { client_action_id: action[:client_action_id], kind: action[:kind] })
    { client_action_id: action.fetch(:client_action_id), status: "failed_retryable", error: "internal error" }
  end

  def actions_params
    params.require(:actions).map { |action| action.permit(:client_action_id, :kind, payload: {}) }
  end
end
