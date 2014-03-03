class StaffAssignmentsController < ApplicationController
  include Permissions

  before_filter :ensure_projects_coordinator
  before_filter :set_page_title

  def create
    @staff = Staff.find(params[:staff_id])
    if params[:campus_id] == "all"
      @staff.update_attribute :view_all_campuses, true
    else
      @staff.update_attribute :view_all_campuses, false
      @staff.add_campus(Campus.find(params[:campus_id]))
    end

    respond_to do |format|
      if @staff.save
        format.html { redirect_to(@staff, :notice => 'Staff was successfully created.') }
        format.xml  { render :xml => @staff, :status => :created, :location => @staff }
        format.js   { render(:inline => "") }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @staff.errors, :status => :unprocessable_entity }
        format.js   { render(:inline => "alert('error')") }
      end
    end
  end

  def destroy
    unless params[:id] == "all"
      @staff_assignment = StaffAssignment.find(params[:id])
      person = @staff_assignment.person
      staff = person.staff
      @staff_assignment.destroy
    else
      staff = Staff.find params[:staff_id]
      staff.update_attribute :view_all_campuses, false
    end

    respond_to do |format|
      format.html { redirect_to(staff) }
      format.xml  { head :ok }
      format.js   { render :inline => "" }
    end
  end

  protected

  def set_page_title
    @page_title = "Tools"
  end
end
