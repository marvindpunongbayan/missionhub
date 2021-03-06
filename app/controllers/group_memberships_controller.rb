class GroupMembershipsController < ApplicationController

  def create
    @group = current_organization.groups.find(params[:group_id]) 
    @inContacts = params[:render_in_contacts].present?
    if params[:from_add_member_screen] == "true"
      @persons = Person.find(params[:person_id])
      if has_permission
        @group_membership = @group.group_memberships.find_or_initialize_by_person_id(@persons.id)
        @group_membership.role = params[:role]
        @group_membership.save
        respond_to do |wants|
          wants.html { render :nothing => true }
          wants.js
        end
      else
        respond_to do |wants|
          wants.html { render :nothing => true }
          wants.js { render 'failed.js.erb' }
        end
        return false
      end
    else
      @persons = Person.find(params[:person_id].split(","))
      if has_permission
        @persons.each do |person|
          @group_membership = @group.group_memberships.find_or_initialize_by_person_id(person.id)
          @group_membership.role = params[:role]
          @group_membership.save
        end
        
        respond_to do |wants|
          wants.html { render :nothing => true }
          wants.js
        end
      else
        respond_to do |wants|
          wants.html { render :nothing => true }
          wants.js { render 'failed.js.erb' }
        end
        return false
      end
    end
  end
  
  def destroy
    @group = current_organization.groups.find(params[:group_id])
    @group_membership = @group.group_memberships.find(params[:id])
    return false unless can?(:manage, current_organization) || @group.leaders.include?(current_person) || @group_membership.person_id == current_person.id
    @group_membership.destroy
    render nothing: true
  end
  
  def search
    if params[:name].present?
      results = Person.search_by_name(params[:name], current_organization.id)
      #raise results.to_sql
      @people = results.includes(:user)
      if params[:show_all].to_s == 'true'
        @total = @people.count
      else
        @total = results.count
        @people = @people.limit(10) 
      end
      render :layout => false
    else
      render :nothing => true
    end
  end
  
  protected
    def has_permission
      return true if can?(:manage, current_organization)
      #return true if can?(:lead, current_organization)
      return true if @group.organization.leaders.include?(current_person)
      return true if @group.list_publicly? && params[:role] == 'interested' && @person == current_person
      return true if @group.public_signup? && params[:role] == 'member' && @person == current_person
      return false
    end
end
