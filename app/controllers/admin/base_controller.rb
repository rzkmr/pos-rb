class Admin::BaseController < ApplicationController
  include RequireAdmin
end
