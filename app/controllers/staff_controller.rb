class StaffController < ApplicationController
  include Permissions

  before_filter :ensure_projects_coordinator
  before_filter :set_page_title
  before_filter :set_layout

  # GET /staffs
  # GET /staffs.xml
  def index
    @staffs = Staff.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @staffs }
    end
  end

  # GET /staffs/1
  # GET /staffs/1.xml
  def show
    @staff = Staff.find(params[:id])

    respond_to do |format|
      format.html { render :layout => false }
      format.xml  { render :xml => @staff }
    end
  end

  # GET /staffs/new
  # GET /staffs/new.xml
  def new
    @staff = Staff.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @staff }
    end
  end

  # GET /staffs/1/edit
  def edit
    @staff = Staff.find(params[:id])
  end

  # POST /staffs
  # POST /staffs.xml
  def create
    @staff = Staff.find_or_create_by_person_id(params[:person_id])
    @staff.add_campus(Campus.find(params[:campus_id]))

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

  # DELETE /staffs/1
  # DELETE /staffs/1.xml
  def destroy
    @staff = Staff.find(params[:id])
    @staff.destroy

    respond_to do |format|
      format.html { redirect_to(staffs_url) }
      format.xml  { head :ok }
      format.js   { render :inline => "" }
    end
  end

  def search
    @found_viewers = Person.search_by_name(params[:text]).collect(&:viewer).compact
    @found_viewers.reject!{ |u| u.person.try(:is_hrdb_staff?) }
    @found_viewers.sort! { |p1, p2| p1.try(:person).try(:full_name) <=> p2.try(:person).try(:full_name) }
  end

  protected

  def set_page_title
    @page_title = "Tools"
  end
end
