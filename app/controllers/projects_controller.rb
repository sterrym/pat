require_dependency 'permissions'
require_dependency 'questionnaire_engine/bulk_printing'

class ProjectsController < ApplicationController
  include Permissions
  include BulkPrinting

  campus_stats_actions = [ :campus_project_acceptance_totals, :campus_project_applying_totals, :projects_count_hash ]

  before_filter :get_project, :except => [ :index ] + campus_stats_actions
  before_filter :ensure_project_staff, :except => campus_stats_actions
  skip_before_filter :verify_user, :only => campus_stats_actions
  skip_before_filter :get_project, :only => campus_stats_actions
  skip_before_filter :verify_event_group_chosen, :only => campus_stats_actions
  skip_before_filter :set_event_group, :only => campus_stats_actions

  def index
    @event_group = params[:event_group_id] ? EventGroup.find(params[:event_group_id]) : @eg
    @projects = @event_group.projects

    respond_to do |format|
      format.json { render :json => {
        :success => true,
        :message => "Loaded data",
        :data => @projects
      } }
    end
  end

  def bulk_summary_forms
    @page_title = "Acceptance Summary Forms"
    form = @eg.application_form
    @questionnaire = form.questionnaire
    @questionnaire.filter = { :filter => [ "in_summary_view" ], :default => false }
    @pages = @questionnaire.pages

    params[:summary] = true
    bulk_forms([ :appln, { :viewer => :persons } ]) do |acc|
      @instances << { :instance => acc.appln,
        :appln => acc.appln,
        :title => "#{acc.viewer.name} Summary Form"
      }
    end
  end

  def bulk_processor_forms
    @page_title = "Acceptance Processor Forms"
    @questionnaire = @eg.forms.find_by_name("Processor Form").questionnaire

    # filter confidential qs out unless user has permission
    @viewer.set_project @project
    unless @viewer.is_eventgroup_coordinator?(@eg) || @viewer.is_processor?
      @questionnaire.filter = { :filter => ['confidential'], :default => true }
    end

    # now that filter is set, get all pages
    @pages = @questionnaire.pages

    bulk_forms([ :appln, { :viewer => :persons } ]) do |acc|
      @instances << { :instance => acc.appln.processor_form,
        :title => "#{acc.viewer.name} Processor Form",
        :appln => acc.appln
      }
    end
  end

  def campus_project_acceptance_totals
    unless params[:campus_ids]
      render :json => { :error => "campus_ids are required" }
    else
      render :json => Project.campus_project_totals(params[:campus_ids], "Acceptance", "accepted_count", params[:project_ids], params[:secondary_sort])
    end
  end

  def campus_project_applying_totals
    unless params[:campus_ids]
      render :json => { :error => "campus_ids are required" }
    else
      render :json => Project.campus_project_totals(params[:campus_ids], "Applying", "applying_count", params[:project_ids])
    end
  end

  def projects_count_hash
    render :json => Project.projects_count_hash(params[:project_ids])
  end

  protected
    
    def get_project
      @project = Project.find params[:id]
    end
end
