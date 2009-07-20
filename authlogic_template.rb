run "rm public/index.html"

# check if we want to use rspec
if yes?("Do you want to use RSpec for testing? (yes/no)")
  plugin "rspec", :git => "git://github.com/dchelimsky/rspec.git"
  plugin "rspec-rails", :git => "git://github.com/dchelimsky/rspec-rails.git"
  generate :rspec
end



# add authlogic config.gem to env
gem "authlogic"

# ---------------------------------------------------------------------------------
#                      models and controllers
# ---------------------------------------------------------------------------------
# create the user model
generate(:scaffold, "user", "login:string", "email:string", "crypted_password:string", "password_salt:string",
          "persistence_token:string", "single_access_token:string", "perishable_token:string")
# add the acts_as_authentic to user model
file("app/models/user.rb") do
  <<-USERCODE
  class User < ActiveRecord::Base
    acts_as_authentic
  end
  USERCODE
end

# setup the users controller
file("app/controllers/users_controller.rb") do
  <<-USERSCONTROLLER
  class UsersController < ApplicationController
    before_filter :require_no_user, :only => [:new, :create]
    before_filter :require_user, :only => [:show, :edit, :update]
    
    def new
      @user = User.new
    end
    
    def create
      @user = User.new(params[:user])
      if @user.save
        flash[:notice] = "Account registered!"
        redirect_back_or_default account_url
      else
        render :action => :new
      end
    end
    
    def show
      @user = @current_user
    end
   
    def edit
      @user = @current_user
    end
    
    def update
      @user = @current_user # makes our views "cleaner" and more consistent
      if @user.update_attributes(params[:user])
        flash[:notice] = "Account updated!"
        redirect_to account_url
      else
        render :action => :edit
      end
    end
  end
  USERSCONTROLLER
end
          
# create the user session model
generate(:session, "user_session")

# create the user sessions controller
file("app/controllers/user_sessions_controller.rb") do
  <<-CODE
  class UserSessionsController < ApplicationController
    before_filter :require_no_user, :only => [:new, :create]
    before_filter :require_user, :only => :destroy
    
    def new
      @user_session = UserSession.new
    end
    
    def create
      @user_session = UserSession.new(params[:user_session])
      @user_session.save do |result|
        if result
          flash[:notice] = "Login successful!"
          redirect_back_or_default account_url
        else
          render :action => :new
        end
      end
    end
    
    def destroy
      current_user_session.destroy
      flash[:notice] = "Logout successful!"
      redirect_back_or_default new_user_session_url
    end

  end
  CODE
end

# setup the application controller
file("app/controllers/application_controller.rb") do
  <<-APPCONTROLLER
  class ApplicationController < ActionController::Base
    helper :all
    helper_method :current_user_session, :current_user
    filter_parameter_logging :password, :password_confirmation
    
    private
      def current_user_session
        return @current_user_session if defined?(@current_user_session)
        @current_user_session = UserSession.find
      end
      
      def current_user
        return @current_user if defined?(@current_user)
        @current_user = current_user_session && current_user_session.record
      end
      
      def require_user
        unless current_user
          store_location
          flash[:notice] = "You must be logged in to access this page"
          redirect_to new_user_session_url
          return false
        end
      end
   
      def require_no_user
        if current_user
          store_location
          flash[:notice] = "You must be logged out to access this page"
          redirect_to account_url
          return false
        end
      end
      
      def store_location
        session[:return_to] = request.request_uri
      end
      
      def redirect_back_or_default(default)
        redirect_to(session[:return_to] || default)
        session[:return_to] = nil
      end
  end
  APPCONTROLLER
end

# ---------------------------------------------------------------------------------
#                      views
# ---------------------------------------------------------------------------------

# users > _form.html.erb
file("app/views/users/_form.html.erb") do
  <<-FORMVIEW
  <%= form.label :login %><br />
  <%= form.text_field :login %><br />
  <br />
  <%= form.label :password, form.object.new_record? ? nil : "Change password" %><br />
  <%= form.password_field :password %><br />
  <br />
  <%= form.label :password_confirmation %><br />
  <%= form.password_field :password_confirmation %><br />
  <%= form.label :email %><br />
  <%= form.text_field :email %><br />
  FORMVIEW
end

# users > edit.html.erb
file("app/views/users/edit.html.erb") do
  <<-EDITVIEW
  <h1>Edit My Account</h1>
 
  <% form_for @user, :url => account_path do |f| %>
    <%= f.error_messages %>
    <%= render :partial => "form", :object => f %>
    <%= f.submit "Update" %>
  <% end %>
   
  <br /><%= link_to "My Profile", account_path %>
  EDITVIEW
end

# users > new.html.erb
file("app/views/users/new.html.erb") do
  <<-NEWVIEW
  <h1>Register</h1>
   
  <% form_for @user, :url => account_path do |f| %>
    <%= f.error_messages %>
    <%= render :partial => "form", :object => f %>
    <%= f.submit "Register" %>
  <% end %>
  NEWVIEW
end

# users > show.html.erb
file("app/views/users/show.html.erb") do
  <<-SHOWVIEW
  <p>
    <b>Login:</b>
    <%=h @user.login %>
  </p>
   
  <p>
    <b>Login count:</b>
    <%=h @user.login_count %>
  </p>
   
  <p>
    <b>Last request at:</b>
    <%=h @user.last_request_at %>
  </p>
   
  <p>
    <b>Last login at:</b>
    <%=h @user.last_login_at %>
  </p>
   
  <p>
    <b>Current login at:</b>
    <%=h @user.current_login_at %>
  </p>
   
  <p>
    <b>Last login ip:</b>
    <%=h @user.last_login_ip %>
  </p>
   
  <p>
    <b>Current login ip:</b>
    <%=h @user.current_login_ip %>
  </p>
   
   
  <%= link_to 'Edit', edit_account_path %>
  SHOWVIEW
end

# user_sessions > new.html.erb
file("app/views/user_sessions/new.html.erb") do
  <<-USNEW
  <h1>Login</h1>
 
  <% form_for @user_session, :url => user_session_path do |f| %>
    <%= f.error_messages %>
    <%= f.label :login %><br />
    <%= f.text_field :login %><br />
    <br />
    <%= f.label :password %><br />
    <%= f.password_field :password %><br />
    <br />
    <%= f.check_box :remember_me %><%= f.label :remember_me %><br />
    <br />
    <%= f.submit "Login" %>
  <% end %>
  USNEW
end


# layouts > application.html.erb
file("app/views/layouts/application.html.erb") do
  <<-APPVIEW
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
   
  <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
  <head>
    <meta http-equiv="content-type" content="text/html;charset=UTF-8" />
    <title><%= controller.controller_name %>: <%= controller.action_name %></title>
    <%= stylesheet_link_tag 'scaffold' %>
    <%= javascript_include_tag :defaults %>
  </head>
  <body>
   
  <h1>Basic App with Authlogic</h1>
  <br />
  <br />
   
   
  <% if !current_user %>
    <%= link_to "Register", new_account_path %> |
    <%= link_to "Log In", new_user_session_path %> |
  <% else %>
    <%= link_to "My Account", account_path %> |
    <%= link_to "Logout", user_session_path, :method => :delete, :confirm => "Are you sure you want to logout?" %>
  <% end %>
   
  <p style="color: green"><%= flash[:notice] %></p>
   
  <%= yield %>
   
  </body>
  </html>
  APPVIEW
end



# ---------------------------------------------------------------------------------
#                      routes
# ---------------------------------------------------------------------------------

# add routes
route "map.resource :user_session"
route "map.root :controller => \"user_sessions\", :action => \"new\""
route "map.resource :account, :controller => \"users\""
route "map.resources :users"

# ---------------------------------------------------------------------------------
#                      database
# ---------------------------------------------------------------------------------
# get the name of the database from user
db_name = ask("What is the DB called? (without _development etc)")
db_user = ask("What is the username for the DB?")
db_pass = ask("What is the password for the DB?")
file("config/database.yml") do
  <<-DBYML
  development:
    adapter: mysql
    database: #{db_name}_development
    username: #{db_user}
    password: #{db_pass}
    host: localhost
    
  test:
    adapter: mysql
    database: #{db_name}_test
    username: #{db_user}
    password: #{db_pass}
    host: localhost

  production:
    adapter: mysql
    database: #{db_name}_production
    username: #{db_user}
    password: #{db_pass}
    host: localhost
  DBYML
end


# ---------------------------------------------------------------------------------
#                      migrations
# ---------------------------------------------------------------------------------

# rake migrations if user wants to
if ask("Do you want to run migrations now? (yes/no)") == "yes"
  rake("db:migrate")
end



