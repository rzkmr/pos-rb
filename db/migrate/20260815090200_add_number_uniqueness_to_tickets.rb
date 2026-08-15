class AddNumberUniquenessToTickets < ActiveRecord::Migration[8.1]
  def change
    # number: table_session.tickets.count + 1 (Ticket.submit!) was never
    # enforced unique at the DB level. Harmless with one writer at a time,
    # but the offline write queue (Phase 2) makes concurrent replay of two
    # queued tickets for the same session a real possibility — without this
    # index they could both compute the same "count + 1" and collide
    # silently instead of raising something Ticket.submit! can recover from.
    add_index :tickets, [ :table_session_id, :number ], unique: true
  end
end
