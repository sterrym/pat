require_dependency 'my_ordered_hash.rb'

class ReportsController < ApplicationController
  include TravelSegmentTagsAutocomplete
  
  before_filter :set_title
  before_filter :set_permissions_level
  before_filter :ensure_is_general_staff
  # they want all staff to be able to see everything..
  #before_filter :ensure_is_projects_coordinator, :except => [ :index, :cm, :crisis_management, :project_stats ]
  before_filter :set_projects, :only => [ :participants, :registrants, :crisis_management, :parental_emails, 
    :ticketing_requests, :funding_status, :funding_details, :viewers_with_profile_for_project,
    :funding_details_costing, :funding_details, :travel_list, :project_stats, :funding_costs,
    :itinerary, :interns, :team_leaders, :summary_forms, :cost_items_for_project, :cost_items, :manual_donations, 
    :prep_items, :prep_items_for_project, :cost_items2, :changed_always_editable_answer_after_date ]
  before_filter :set_viewer, :only => [ :funding_details_costing, :funding_details, :funding_costs ]
  before_filter :set_travel_segment, :only => [ :travel_segment, :custom_itinerary ]
  before_filter :set_cost_items, :only => [ :cost_items ]
  before_filter :set_prep_items, :only => [ :prep_items ]
  before_filter :set_skip_title
  before_filter :try_to_delete_invalid_apps, :only => [ :project_stats ]
  
  def index
    projects = @eg.projects
    if @viewer.is_eventgroup_coordinator?(@eg)
      @project_with_full_view = projects
      @project_director_projects = projects
    else
      @project_with_full_view = []
      @project_director_projects = []
      projects.each do |p|
        @viewer.set_project p
        if @viewer.is_project_administrator? || @viewer.is_project_director?
          
          @project_with_full_view << p
          @project_director_projects << p
          
        elsif @viewer.is_project_staff?
          @project_with_full_view << p
        end
      end
    end
    
    @project_with_full_view.sort! { |a,b| a.title <=> b.title }
  end
  
  def pdf
    generator = IO.popen("htmldoc -t pdf --path \".;http://#{@request.env["HTTP_HOST"]}\" --webpage -", "w+")
    generator.puts @template.render("reports/pdf_test_content")
    generator.close_write

    send_data(generator.read, :filename => "test.pdf", :type => "application/pdf")
  end

  def mk_sel(s)
    #for klass in [ Person, Campus, Assignment, YearInSchool, Project, Profile ]
    for klass in [ Person, Campus, SchoolYear, Project, Profile ]
      s.gsub!(klass.name, klass.table_name)
    end
    logger.info s
    s
  end

  Registrant = Struct.new(:last_name, :first_name, :gender, :campus, :year, :status, :pref1, :pref2, :accepted, :phone, :email)
  def registrants
    @columns = MyOrderedHash.new( [
      :last_name, 'string',
      :first_name, 'string',
      :gender, 'string',
      @eg.has_your_campuses ? [ :campus, 'string' ] : nil,
      @eg.has_your_campuses ? [ :year, 'int' ] : nil,
      :status, 'string',
      :pref1, 'string',
      :pref2, 'string',
      :accepted, 'string',
      :phone, 'string',
      :email, 'string'
    ].flatten.compact )
    @rows = [ ]

    @page_title = (@many_projects ? @eg.title : @project_title) + " Registrants"

    # this is gonna be awesome
# as awesome as this may be, I'm disabling it to get the reports working in utopian
# schema
=begin
    applns = Appln.find_all_by_preference1_id(@projects_ids, :include =>
      [ :preference1, :preference2,
        { :profiles =>
          [ :project,
            { :viewer =>
              { :persons =>
                { :person_years => :year_in_school, :assignments => :campus
                }
              }
            }
          ]
        }
      ],
      :select => mk_sel("Person.last_name, Person.first_name, Person.gender_id, Campus.campus_shortDesc, Assignment.assignmentstatus_id, YearInSchool.year_desc, Project.title, Profile.status, Profile.type, Person.person_local_phone, Person.person_email")
    )
=end
    applns = Appln.find_all_by_preference1_id(@projects_ids, :include => 
      [ :preference1, :preference2,
        { :profiles => 
          [ :project ],
        }
      ]
    )

    #@rows = [ [  ] ]
    @rows = applns.collect{ |appln|
      profile = appln.profile
      viewer = appln.profile.viewer
      person = viewer.person

      [
        person.preferred_last_name,
        person.preferred_first_name,
        person.gender_short,
        @eg.has_your_campuses ? person.campus_abbrev(:search_arrays => true) : :skip,
        @eg.has_your_campuses ? person.try(:year_in_school).try(:name) : :skip,
        profile.status,
        appln.preference1.title,
        (appln.preference2.title if appln.preference2),
        if profile.class == Acceptance then profile.project.title end,
        person.current_address.phone,
        person.email
      ].delete_if{ |i| i == :skip }
    }

    render_report @rows
  end
  
  def participants
    @columns = MyOrderedHash.new( [
      :last_name, 'string',
      :first_name, 'string',
      :gender, 'string',
      :project, 'string',
      @eg.has_your_campuses ? [ :campus, 'string' ] : nil,
      @eg.has_your_campuses ? [ :year, 'int' ] : nil,
      :phone, 'string',
      :cell, 'string',
      :email, 'string'
    ].flatten.compact )
    @rows = [ ]

    @page_title = @projects.collect(&:title).join(', ') + " Participants"

    conditions = []
    conditions << "(as_intern is false OR as_intern is null)" if params[:hide_interns] == 'true'
    conditions << "(as_team_leader is false OR as_team_leader is null)" if params[:hide_team_leaders] == 'true'

    acceptances = Acceptance.find_all_by_project_id(@projects_ids, :include => [
        :project
      ],
      :select => mk_sel("Person.last_name, Person.first_name, Person.gender_id, Campus.campus_shortDesc, Assignment.assignmentstatus_id, YearInSchool.year_desc, Project.title, Profile.status, Profile.type, Person.person_local_phone, Person.cell_phone, Person.person_email"),
      :conditions => conditions.join(" AND ")
    )

    #@rows = [ [  ] ]
    @rows = acceptances.collect{ |acceptance|
      viewer = acceptance.viewer
      person = viewer.person

      [
        person.preferred_last_name,
        person.preferred_first_name,
        person.gender_short,
        acceptance.project.title,
        @eg.has_your_campuses ? person.campus_abbrev(:search_arrays => true) : :skip,
        @eg.has_your_campuses ? person.year_in_school.year_desc : :skip,
        person.person_local_phone,
        person.cell_phone,
        person.person_email
      ].delete_if{ |i| i == :skip }
    }

    render_report @rows
  end
 
  CMRegistrant = Struct.new(:reg, :with_group, :plans)
  def cm
    # apparently everyone should be able to see everyone's cm 2007 plans...
    @projects = @eg.projects
    @projects_ids = @projects.collect{ |p| p.id }
    
    @cm_registrants = []
    registrants_only do |v, a, registrant|
      if !a.nil? && extract_form_answer(:attending_cm, a) == "Yes"
        @cm_registrants << CMRegistrant.new(registrant, extract_form_answer(:cm_travel_with_group, a), extract_form_answer(:cm_plans, a))
      end
    end
    @columns[:with_group] = 'string'
    @columns[:plans] = 'string'
    @default_sort = :pref1
    
    @page_title = "#{@eg.title} CM -- Registrants who are going to CM 2007."
    render_report @cm_registrants
  end
  
  def ticketing_requests
    @columns = MyOrderedHash.new [
    :last_name, 'string', 
    :first_name, 'string',
    :legal_name, 'string',
    :gender, 'string',
    :staff, 'string',
    @include_pref1_applns ? [ :status, 'string' ] : nil,
    :project, 'string',
    :birthdate, 'string',
    :departure_city, 'string',
    :passport_number, 'string',
    :passport_country, 'string',
    :passport_expiry, 'int',
    :cm2007, 'string',
    :intern, 'string',
    :notes, 'string'
    ].compact.flatten
    
    @participants = []
    
    loop_reports_viewers(@projects_ids, @include_pref1_applns, true) do |ac,a,v,p|
      
      if v.is_student?(@eg)
        departure = extract_form_answer(:departure_city, a)
        other = extract_form_answer(:departure_other, a)
        if other =~ /\S/ then departure += " other: " + other end
        legal_name = extract_form_answer(:first_name, a) + " " + extract_form_answer(:middle_name, a) + " " + extract_form_answer(:last_name, a)
        birthdate = extract_form_answer(:birthdate, a)
        passport_number = extract_form_answer(:passport_number, a)
        passport_country = extract_form_answer(:passport_country_origin, a)
        passport_expiry = extract_form_answer(:passport_expiry, a)
        cm2007 = (extract_form_answer(:attending_cm, a) == "Yes" ? 'cm2007' : '')
        notes = extract_form_answer(:travel_request_notes, a)
      else
        departure = ''
        other = ''
        legal_name = v.name
        ec_entry = p.emerg
        birthdate = ec_entry ? ec_entry.emerg_birthdate : ''
        passport_number = ''
        passport_country = ''
        passport_expiry = ''
        cm2007 = ''
        notes = ''
      end
      
      gender = p.gender
      
      @participants << [ p.last_name.capitalize, p.first_name.capitalize, legal_name, gender, v.is_current_staff?(@eg) ? 'staff' : '',
        @include_pref1_applns ? (ac ? 'accepted' : a.status) : nil, ac ? ac.project.title : a.preference1.title, 
        birthdate, departure, passport_number, passport_country, passport_expiry, cm2007, 
        ((ac && ac.as_intern?) || (ac.nil? && a.as_intern?) ? 'intern' : ''), notes ].compact
    end
    
    @page_title = "#{@eg.title} #{@project_title} Ticketing Requests #{@include_pref1_applns ? ' plus pref1s' : ''}"
    render_report @participants
  end
  
  def itinerary
    @profiles = []
    @editors = "restricted"
    @page_title = "#{@eg.title} #{@project_title} Itinerary"
    @include_profiles = true.to_s
    
    loop_reports_viewers(@projects_ids, false, true) do |profile,a,v,person|
      name = if person then person.full_name elsif v then 
         v.username else "? (profile id=#{profile.id})" end
      @profiles << [ name, profile.project, profile ]
    end

    render_report nil
  end

  def processor_forms
    redirect_to :controller => :projects, 
                :action => :bulk_processor_forms, 
                :id => params[:project_id],
                :view => 'print',
                :viewer_id => params[:viewer_id],
                :print => params[:format]
  end

  def summary_forms
    redirect_to :controller => :projects, 
                :action => :bulk_summary_forms, 
                :id => params[:project_id],
                :view => 'print',
                :viewer_id => params[:viewer_id],
                :print => params[:format]
  end
  
  def generate_cache(viewer_ids)
    viewer_ids << -100 # -100 as some bogus id so that the IN ( ) sql stmt doesn't give an error when empty
    viewer_ids.delete_if { |vid| vid.nil? || vid == '' }
    viewers = Viewer.find :all, :conditions => "accountadmin_viewer.viewer_id IN (#{viewer_ids.join(',')})", :include => :access
    viewers_cache = {}
    viewers.each { |v| viewers_cache[v.id] = v }
    
    person_ids = viewers.collect{|v| v.access.person_id }.compact
    persons = Person.find person_ids
    persons_cache = {}
    persons.each { |p| persons_cache[p.id] = p }
    
    [ viewers_cache, persons_cache ]
  end
  
  def make_answers_cache(instance_list)
    @@form_elements[@eg.id] ||= { :values => [] }
    return if @@form_elements[@eg.id][:values].nil? || @@form_elements[@eg.id][:values].empty?
    Answer.find_all_by_question_id_and_instance_id @@form_elements[@eg.id][:values].uniq, instance_list.collect{|ins| ins.id}
  end
  
  # lets me switch from the optimized one and old one quickly
  def loop_reports_viewers_switch(project_ids, include_pref1_applns = false)
    loop_reports_viewers(project_ids, include_pref1_applns) do |ac,a,v,p|
      yield ac,a,v,p
    end
  end
  
  def loop_reports_viewers_old(project_ids, include_pref1_applns = false)
    
    accepted = Acceptance.find_all_by_project_id(project_ids)
    accepted.each do |ac|      
      a = ac.appln
      v = a.viewer
      p = v.person
      
      yield ac,a,v,p
    end
    
    if include_pref1_applns
      # go through everyone who has pref 1
      pref1s = Appln.find_all_by_preference1_id(project_ids)
      pref1s.each do |a|
        next if a.acceptance
        v = a.viewer
        next if v.nil?
        p = v.person
        
        yield nil,a,v,p
      end
    end
  end
  
  # -loops through all viewers set by project_ids, calling yield
  # -special if include_pref1_applns is true it will
  #  loop through all viewers with an application with pref 1 set
  #  to a project in project_ids
  # -now optimized, to the detriment of readability, but it's from 30s -> 5s ???!?!?!?! is it??!?!
  #    because it does mass select statements instead of looping through each one
  def loop_reports_viewers(project_ids, include_pref1_applns = false, include_staff = false)
    accepted = Acceptance.find_all_by_project_id(project_ids, :include => [ :project, :appln ])
    viewer_ids = accepted.collect{ |ac| ac.viewer_id }
    viewers_cache, persons_cache = generate_cache(viewer_ids)
    applns_list = Appln.find :all, :conditions => "viewer_id in (#{viewer_ids.join(',')})", :include => :processor_form_ref
    applns = {}
    applns_list.each do |a| applns[a.id] = a end
    
    accepted.sort!{ |a1, a2|
      v1 = viewers_cache[a1.viewer_id]
      v2 = viewers_cache[a2.viewer_id]
      p1 = persons_cache[v1.access.person_id]
      p2 = persons_cache[v2.access.person_id]

      v1.name <=> v2.name
    }

    accepted.each do |ac|
      a = applns[ac.appln_id] || ac.appln
      next if a.nil?
      v = viewers_cache[a.viewer_id] || ac.viewer
      @answers_cache = make_answers_cache [ a, a.processor_form ]
      yield ac, a, v, persons_cache[v.access.person_id]
    end
    
    if include_pref1_applns
      # go through everyone who has pref 1
      pref1s = Appln.find_all_by_preference1_id(project_ids, :include => :preference1, :include => :processor_form_ref)
      pref1_ids = pref1s.collect{|a| a.id } << -100
      pref1s_acceptances_list = Acceptance.find :all, :conditions => "appln_id in (#{pref1_ids.join(',')})"
      pref1s_a_to_ac = {}
      pref1s_acceptances_list.each do |ac| pref1s_a_to_ac[ac.appln_id] = ac end
      viewers_cache, persons_cache = generate_cache(pref1s.collect{ |a| a.viewer_id })
      
      pref1s.each do |a|
        next if pref1s_a_to_ac[a.id]
        v = viewers_cache[a.viewer_id]
        next if v.nil?
        @answers_cache = make_answers_cache [ a, a.processor_form ]
        
        yield nil, a, v, persons_cache[v.access.person_id]
      end
    end
    
    if include_staff
      staff_profiles = StaffProfile.find_all_by_project_id(project_ids)
      viewers_cache, persons_cache = generate_cache(staff_profiles.collect{ |profile| profile.viewer_id })

      for staff_profile in staff_profiles
        v = viewers_cache[staff_profile.viewer_id]

	person = nil
	person = persons_cache[v.access.person_id] if v && v.access
	
        yield staff_profile, nil, v, person
      end
    end
  end
  
  EmergencyContact = Struct.new(:name, :relation, :home_number, :work_number, :cell_number, :email)
  PassportInfo = Struct.new(:number, :expiry, :country)
  EmergencyInfo = Struct.new(:cond, :meds)
  ProjectEmergencyParticipant = Struct.new(:last_name, :first_name, :project, :gender, :staff, :birthdate, :passport, 
                                           :emergency_info, :contact1, :contact2)
  HealthInfo = Struct.new(:number, :province)
  InsuranceInfo = Struct.new(:carrier, :number)
  DoctorsInfo = Struct.new(:doctors_name, :doctors_phone, :dentist_name, :dentist_phone)
  def crisis_management
    
    @columns = MyOrderedHash.new [
    :last_name, 'string', 
    :first_name, 'string',
    @many_projects ? [ :project, 'string' ] : nil,
    :gender, 'string',
    :staff, 'string', 
    :curr_prov, 'string',
    :perm_prov, 'string',
    :birthdate, 'string',
    :passport_number, 'string',
    :passport_expiry, 'int',
    :passport_country, 'string',
    :have_conditions, 'string',
    :have_meds, 'string',
   ].compact.flatten
    @columns.merge! emergency_contact_columns('c1_')
    @columns.merge! emergency_contact_columns('c2_')
    @columns.merge! MyOrderedHash.new([
    :health_number, 'string',
    :health_province, 'string',
    :ins_carrier, 'string',
    :ins_number, 'string',
    :doc_name, 'string',
    :doc_phone, 'string',
    :dentist_name, 'string',
    :dentist_phone, 'string'
    ])
 

    # index where the sub objects are so they can be referenced directly in the partial
    pp_pos = @columns.position(:passport_number)
    @index = { :passport => pp_pos, :emerg => pp_pos+1, :c1 => pp_pos+2, :c2 => pp_pos+3, 
               :hinfo => pp_pos+4, :hins => pp_pos+5, :doctors => pp_pos+6 }

    @registrants = []
    
    loop_reports_viewers(@projects_ids, @include_pref1_applns, true) do |ac,a,v,p|
      
      gender = p.gender

      ec_entry = p.get_emerg

      empty_wc = EmergencyContact.new('','','','','','')

      emergency_contact_1 = EmergencyContact.new(ec_entry.emerg_contactName,
                              ec_entry.emerg_contactRship,
                              ec_entry.emerg_contactHome,
                              ec_entry.emerg_contactWork,
                              ec_entry.emerg_contactMobile,
                              ec_entry.emerg_contactEmail)

      emergency_contact_2 = EmergencyContact.new(ec_entry.emerg_contact2Name,
                              ec_entry.emerg_contact2Rship,
                              ec_entry.emerg_contact2Home,
                              ec_entry.emerg_contact2Work,
                              ec_entry.emerg_contact2Mobile,
                              ec_entry.emerg_contact2Email)

      emergency_info = EmergencyInfo.new(ec_entry.emerg_medicalNotes, ec_entry.emerg_meds)

      birthdate = ec_entry ? ec_entry.emerg_birthdate : ''
      birthdate = birthdate.to_s # might be nil

      passport_info = get_passport_info(ac, p, a, ec_entry)
      
      hp = ec_entry.health_state.try(:name)
      health_info = HealthInfo.new(ec_entry.health_number, hp)
      ins_info = InsuranceInfo.new(ec_entry.medical_plan_carrier, ec_entry.medical_plan_number)
      doc_info = DoctorsInfo.new(ec_entry.doctor_name.to_s, ec_entry.doctor_phone.to_s,
                                 ec_entry.dentist_name.to_s, ec_entry.dentist_phone.to_s) 

      @registrants << [ p.preferred_last_name.capitalize, p.preferred_first_name.capitalize, @many_projects ? ac.project.title : nil, gender,
        v.is_current_staff?(@eg) ? 'staff' : '', 
        p.try(:local_state) || '',
        p.try(:permanent_state) || '',
        birthdate, passport_info,
        emergency_info, emergency_contact_1, emergency_contact_2,
        health_info, ins_info, doc_info ].compact
    end
 
    @page_title = "#{@eg.title} #{@project_title} Crisis Management Report"
    render_report @registrants
  end
  
  StatEntry = Struct.new(:project, :started, :submitted, :completed, :accepted, :interns_and_team_leaders, :interns, :team_leaders, :total, :declined, :withdrawn)
  def project_stats
    
    @columns = MyOrderedHash.new [
    :project, 'string', 
    :started, 'int',
    :submitted, 'int',
    :completed, 'int',
    :accepted, 'int',
    ([:interns_and_team_leaders, 'int'] if @eg.has_team_leaders && @eg.has_interns),
    ([:interns, 'int'] if @eg.has_interns),
    ([:team_leaders, 'int'] if @eg.has_team_leaders),
    :total_first_5, 'int',
    :declined, 'int',
    :withdrawn, 'int'
    ].compact.flatten
    
    # special case for people assigned to the regional/national campus
    # they can see everything
    if @viewer.person && @viewer.person.campuses.find(:first, :conditions => { Campus._(:abbrv) => 'Reg/Nat' })
      @projects = @eg.projects
    end

    @stats = []
    totals = {}
    sql_intern = "(as_intern = 1)"
    sql_team_leader = "(as_team_leader = 1)"
    sql_not_intern = "(as_intern IS NULL OR as_intern = 0)"
    sql_not_team_leader = "(as_team_leader IS NULL OR as_team_leader = 0)"
    @projects.each do |p|
      stat = StatEntry.new(p.title,

      Applying.find_all_by_status_and_project_id('started', p.id).size,
      
      Applying.find_all_by_project_id_and_status(p.id, 'submitted').size,
      
      Applying.find_all_by_project_id_and_status(p.id, 'completed').size,
      
      Acceptance.find(:all, :conditions => ["project_id = ? AND #{sql_not_intern} AND #{sql_not_team_leader}", p.id]).size, # accepted
      @eg.has_team_leaders && @eg.has_interns? ?
        Acceptance.find(:all, :conditions => ["project_id = ? AND #{sql_intern} AND #{sql_team_leader}", p.id]).size : :skip, # intern and team leader
      @eg.has_interns ? 
        Acceptance.find(:all, :conditions => ["project_id = ? AND #{sql_intern} AND #{sql_not_team_leader}", p.id]).size : :skip, # intern only
      @eg.has_team_leaders ?
        Acceptance.find(:all, :conditions => ["project_id = ? AND #{sql_not_intern} AND #{sql_team_leader}", p.id]).size : :skip, # team leader only
      nil,
      Withdrawn.find_all_by_status_and_project_id('declined', p.id).size,
      Withdrawn.find_all_by_status_and_project_id(['self_withdrawn','admin_withdrawn'], p.id).size)
      
      # set total for first 7 columns
      stat[:total] = stat[:started] + stat[:submitted] + stat[:completed] + stat[:accepted] + 
        (@eg.has_team_leaders && @eg.has_interns ? stat[:interns_and_team_leaders] : 0) +
        (@eg.has_interns ? stat[:interns] : 0) +
        (@eg.has_team_leaders ? stat[:team_leaders] : 0)
      
      @stats << stat
      
      StatEntry.members.each do |m|
        next if m == 'project'
        ms = :"#{m}"
        if stat[ms] == :skip
          totals[ms] = :skip
        else
          totals[ms] = 0 if !totals[ms]
          totals[ms] += stat[ms]
        end
      end
    end
    @stats << StatEntry.new('', totals[:started].to_s, 
    totals[:submitted].to_s, totals[:completed].to_s, 
    totals[:accepted].to_s, 
    totals[:interns_and_team_leaders] == :skip ? :skip : totals[:interns_and_team_leaders].to_i,
    totals[:interns] == :skip ? :skip : totals[:interns].to_i,
    totals[:team_leaders] == :skip ? :skip : totals[:team_leaders].to_i,
    totals[:total], 
    totals[:declined], 
    totals[:withdrawn]
                           ) if @many_projects
    @page_title = "#{@eg.title} #{@project_title} Summer Stats"
    render_report @stats
  end
  
  ParticipantAndParent = Struct.new(:first, :last, :gender, :parent)
  def parental_emails
    
    @columns = MyOrderedHash.new [
    :participant_first_name, 'string', 
    :participant_last_name, 'string',
    :participant_gender, 'string',
    :staff, 'string', 
    ]
    @columns[:project] = 'string' if @many_projects
    @columns.merge! emergency_contact_columns('contact_')
    
    @participants = []
    
    loop_reports_viewers(@projects_ids, @include_pref1_applns, true) do |ac,a,v,p|
      
#      a = ac.appln
#      v = a.viewer
#      p = v.person
      
      if ac.class == Acceptance
        ec = emergency_contact(1, a)
      elsif ac.class == StaffProfile
        ec_entry = p.emerg
        empty_wc = EmergencyContact.new('','','','','','')
        ec = if ec_entry
          EmergencyContact.new(ec_entry.emerg_contactName,
                               ec_entry.emerg_contactRship,
                               ec_entry.emerg_contactHome,
                               ec_entry.emerg_contactWork,
                               ec_entry.emerg_contactMobile,
                               ec_entry.emerg_contactEmail)
        else
          empty_wc
        end
      end
      
      gender = p.gender
      
      @participants << [ p.last_name.capitalize, p.first_name.capitalize, gender, v.is_current_staff?(@eg) ? 'staff' : '', @many_projects ? ac.project.title : nil, ec ].compact
    end
        
    @page_title = "#{@eg.title} #{@project_title} Parental Emails"
    render_report @participants
  end
  
  def funding_status()
    @columns = MyOrderedHash.new [
    :name, 'string', 
    :gender, 'string',
    :staff, 'string',
    @many_projects ? [ :project, 'string' ] : nil,
    :received, 'currency',
    :claimed, 'currency',
    :target, 'currency',
    :outstanding, 'currency',
    :amount_to_raise, 'currency',
    ].flatten.compact
    
    @participants = []
    totals = {}
    
    loop_reports_viewers(@projects_ids, @include_pref1_applns, true) do |ac,a,v,p|
      
      next if v.nil?

      participant = funding_details_for_participant(ac, v, p)
      @participants << participant
      
      c_i = 0
      @columns.each_pair do |c,t|
        if t == 'currency'
          totals[c] ||= 0.0
          totals[c] += participant[c_i].to_f
        end
        c_i += 1
      end
    end
    
    totals[:name] = '' # clear name
    totals[:project] = '' if @many_projects # clear project
    @participants << @columns.collect{ |pair| totals[pair[0]] }
    
    @page_title = "#{@eg.title} #{@project_title} Funding Status Report"
    render_report @participants
  end
  
  def funding_details_for_participant(ac, v, p)
    received = 0
    claimed = 0
    target = 0

    received = ac.donations_total
    target = ac.funding_target(@eg)
    claimed = ac.support_claimed.to_f.to_s

    gender = if p then p.gender_short else 'unknown' end
    staff = if v.nil? then 'missing viewer' else (v.is_current_staff?(@eg) ? 'staff' : '') end
     
    participant = [ p ? p.full_name : 'unknown' , gender, staff, (@many_projects ? ac.project.title : nil),
    received, claimed, target, target - received, target - claimed.to_f ].compact
  end

  def funding_details_costing
    render :inline => render_component_as_string(:action => 'funding_details', :params => params) + "\r\n\r\n" + 
    render_component_as_string(:action => 'funding_costs', :params => params)
  end
  
  def funding_details
    # find profile 
    profiles = Profile.find_all_by_project_id_and_viewer_id @projects.collect { |p| p.id }, @report_viewer.id
    if profiles.length > 1
      # take the first one that has donations if there are multiple profiles
      profile = profiles.detect{ |profile| profile.donations.present? } || profiles.first
    else
      profile = profiles.first
    end
    
    if profile.nil?
      flash[:notice] = "Couldn\'t find a profile for #{@report_viewer.name}."
      @rows = []
      return
    end
    
    # got a profile , now print all the donations that have come in for that acceptance
    columns = [ 'donor_name',
      [ 'donation_type', 'type' ], 
      [ 'donation_reference_number', 'reference' ], 
      [ 'donation_date', 'date'] , 
      [ 'original_amount', 'orig_amount' ],
      [ 'amount', 'amount' ],
      [ 'conversion_rate', 'conv_rate' ],
      'status'
    ]

    @columns = columns_from_model AutoDonation, columns # used for client-side javascript sorting
    @columns['orig_amount'] = 'currency'
    @columns['conv_rate'] = 'currency'
    @columns['amount'] = 'currency'
    @columns['status'] = 'string' # for manual donations
    
    @rows = get_rows(profile.donations, columns)
    
    # fix status since get_rows uses model[attribute] which bypasses
    # the code that removes status for non-USDMANUAL donations
    status_column = columns.index 'status'
    profile.donations.each_with_index do |d,i|
      @rows[i][status_column] = d.status if d.respond_to?(:status)
    end

    # some totals at the bottom
    @rows << [ 'total', '', '', '', profile.donations_total(:orig => true), profile.donations_total ]
    
    @page_title = "#{@eg.title} #{@project_title} #{@report_viewer.name} Funding Details Report"
    render_report @rows
  end
  
  def funding_costs_rows
    @columns = MyOrderedHash.new [
        'type', 'string',
        'amount', 'currency',
    ]
    
    # grab the first profile found if multiple projects were passed
    profiles = Profile.find_all_by_viewer_id_and_project_id @report_viewer.id, 
                  @projects.collect{|p| p.id}, :include => :optin_cost_items
    profile = profiles[0]
    
    total, *types = profile.costing(@eg)
    
    @rows = []
    types.each { |type| 
      @rows << [ type[:name], nil ]
      type[:items].each do |item|
        @rows << [ item.description, item.amount ]
      end
    }
    
    total = profile.donations_total
    target = profile.funding_target(@eg)
    
    @rows << [ 'total', total ]
    @rows << [ 'target', target ]
    @rows << [ 'shortfall', target - total ]
  end
  
  def funding_costs
    funding_costs_rows
    @page_title = "#{@eg.title} #{@project_title} #{@report_viewer.name} Funding Costs"
    render_report @rows, :sortable => false
  end
  
  def project_paperwork
  end
  
  def travel_list
    @columns = MyOrderedHash.new [
    :name, 'string',
    :legal_last_name, 'string', 
    :legal_first_name, 'string', 
    @include_pref1_applns ? [ :status, 'string' ] : nil,
    @many_projects ? [ :project, 'string' ] : nil,
    :gender, 'string',
    :birthdate, 'string',
    :passport_number, 'string',
    :passport_expiry, 'string',
    :passport_country, 'string',
    ].flatten.compact
    
    @participants = []
    
    loop_reports_viewers(@projects_ids, @include_pref1_applns, true) do |ac,a,v,p|
      
      ec_entry  = p.emerg if p
      birthdate = ec_entry ? ec_entry.emerg_birthdate : ' '
      passport_info = get_passport_info(ac, p, a, ec_entry)

      gender = p.try(:gender) || '?'
      
      if v && p
        last_name = p.preferred_last_name.capitalize
        first_name = p.preferred_first_name.capitalize
        legal_last_name = p.legal_last_name
        legal_first_name = p.legal_first_name
      elsif v && !p
        last_name = 'no person'
        first_name = "vid #{v.username}"
        legal_last_name = ''
        legal_first_name = ''
      elsif !v && !p
        last_name = 'no viewer'
        first_name = ''
        first_name = ''
        legal_last_name = ''
        legal_first_name = ''
      end

      @participants << [ "#{first_name} #{last_name}", legal_last_name, legal_first_name,
        @include_pref1_applns ? (ac ? 'accepted' : a.status) : nil, 
        @many_projects ? (ac ? ac.project.title : a.preference1.title) : nil, 
        gender, birthdate, passport_info, 
        ].compact
    end
    
    @page_title = "#{@eg.title} #{@project_title} Travel List #{@include_pref1_applns ? ' plus pref1s' : ''}"
    render_report @participants
  end
  
  # returns a select list with viewers who are accepted to the projects given
  def viewers_with_profile_for_project
    profiles = Profile.find_all_by_project_id @projects_ids, :include => { :viewer => :persons }
    @profile_type_and_viewers = profiles.reject{ |p| p.viewer.nil? }.collect{ |p| [ p.class.name, p.viewer ] }
    
    # sort first by type of profile, then by name
    @profile_type_and_viewers.sort!{ |a,b| 
      klass_a, viewer_a = a
      klass_b, viewer_b = b

      if klass_a != klass_b
        klass_a <=> klass_b
      else
        viewer_a.name <=> viewer_b.name
      end
    }

    @id = params[:dom_id]
    render :layout => !request.xml_http_request?
  end
  
  def cost_items
   @page_title = "People for " + if @cost_items.size == @eg.cost_items.size then
        "All Cost Items"
      elsif @cost_items.size == 1
        "Cost Item " + @cost_items[0].shortDesc
      else
        "Chosen Cost Items"
      end + " in " + if @projects.size == @eg.projects.size then
        "Any Project"
      elsif @projects.size == 1
        @projects[0].title
      else
        "Various Projects"
      end

    @columns = MyOrderedHash.new [
    :name, 'string',
    :gender, 'string',
    :staff, 'string',
    @many_projects ? [ :project, 'string' ] : nil,
    :received, 'currency',
    :claimed, 'currency',
    :target, 'currency',
    :outstanding, 'currency',
    ].flatten.compact

    @participants = []
    added_profile_id = [] 

    for ci in @cost_items
      for profile in (ci.optional? ? 
       ci.optins.collect{ |optin| optin.profile } : 
       Profile.find_all_by_project_id(ci.project.id))

        next if profile.nil? || !@projects.include?(profile.project)
        v = profile.viewer
        p = v.person
        next if v.nil? || p.nil? || added_profile_id[profile.id]
        added_profile_id[profile.id] = true

        @participants << funding_details_for_participant(profile, v, p)
      end
    end

    render_report @participants, :action => :funding_status
  end

  def cost_items2
    if params[:viewer_id] == "all" && params[:project_id] == "all"
      @page_title = "Cost Items for all people for all projects"
    elsif params[:viewer_id] == "all" && params[:project_id] != "all"
      @page_title = "Cost Items for all people for #{@projects.collect(&:title).join(',')}"
    elsif params[:viewer_id] != "all" && params[:project_id] != "all"
      set_viewer
      @page_title = "Cost Items for #{@report_viewer.name} people for #{@projects.collect(&:title).join(',')}"
    end

    @columns = MyOrderedHash.new [
    :person, 'string',
    @many_projects ? [ :project, 'string' ] : nil,
    :cost_item_level, 'string',
    :cost_item_description, 'string',
    :cost_item_amount, 'currency',
    :total, 'currency',
    ].flatten.compact

    @rows = []
    @profiles = params[:viewer_id] == "all" ? @projects.collect(&:profiles).flatten : 
      Profile.find_all_by_project_id_and_viewer_id(@projects.collect { |p| p.id }, @report_viewer.id)

    @profiles.each do |profile|
      name = profile.viewer.name
      @rows << [ name, @many_projects ? profile.project.title : nil,
        "", "", "", "", "" ].compact
      if profile.respond_to?(:all_cost_items)
        profile.all_cost_items(@eg, false, true).each do |ci|
          @rows << [ name, @many_projects ? profile.project.title : nil, ci.short_type, ci.description, ci.amount, "" ].compact
        end
        @rows << [ name, @many_projects ? profile.project.title : nil, "", "", "", profile.funding_target(@eg) ].compact
      end
    end

    render_report @rows
  end

  def cost_items_for_project
    @cost_items = []
    @projects.each do |p|
      @cost_items += p.all_cost_items(@eg)
    end
    @cost_items = @cost_items.uniq
    @id = params[:dom_id]
  end

  def prep_items_for_project
    @prep_items = []
    @projects.each do |p|
      @prep_items += p.prep_items
    end
    @prep_items += @eg.prep_items
    @prep_items = @prep_items.uniq
    @id = params[:dom_id]
  end
  
  def interns
    @columns = MyOrderedHash.new [
    :last_name, 'string', 
    :first_name, 'string',
    @many_projects ? [ :project, 'string' ] : nil,
    :gender, 'string',
    :email, 'string',
    ].flatten.compact
    
    @participants = []
    loop_reports_viewers(@projects_ids, @include_pref1_applns, false) do |ac,a,v,p|
      if ac && ac.as_intern?
        gender = p.gender
      
        @participants << [ p.last_name.capitalize, p.first_name.capitalize, 
          @many_projects ? (ac ? ac.project.title : a.preference1.title) : nil, 
          gender, p.person_email ].compact
      end
    end
    
    @page_title = "#{@eg.title} #{@project_title} Interns"
    render_report @participants
  end

  def team_leaders
    @columns = MyOrderedHash.new [
    :last_name, 'string', 
    :first_name, 'string',
    @many_projects ? [ :project, 'string' ] : nil,
    :gender, 'string',
    :email, 'string',
    ].flatten.compact
    
    @participants = []
    loop_reports_viewers(@projects_ids, @include_pref1_applns, false) do |ac,a,v,p|
      if ac && ac.as_team_leader?
        gender = p.gender
      
        @participants << [ p.last_name.capitalize, p.first_name.capitalize, 
          @many_projects ? (ac ? ac.project.title : a.preference1.title) : nil, 
          gender, p.person_email ].compact
      end
    end
    
    @page_title = "#{@eg.title} #{@project_title} Team Leaders"
    render_report @participants
  end
  
  def travel_segment
    @travel_segments_hash = MyOrderedHash.new;
    @travel_segments.each do |ts|
      @travel_segments_hash[ts] = []
      ts.profiles.each do |p|
        @travel_segments_hash[ts] << [ p.viewer.try(:name), p.project, p ]
      end
    end
    @travel_segments_hash.keys.sort!{ |k,k2| k.departure_time <=> k2.departure_time }
    
    if @travel_segments.size == TravelSegment.find(:all).length 
      tag = "all Travel Segments" 
    elsif @travel_segments.size == 1
      tag = "Travel Segment " + (@travel_segments[0].short_desc if !csv_requested).to_s
    else
      tag = "selected Travel Segments"
    end
    
    @page_title = "#{@eg.title} #{@project_title} Profiles with " + tag
     
    @include_profiles = [true.to_s, 1.to_s].include? params[:include_profiles].to_s
    
    # restrict profile columns
    @editors = 'restricted'
    
    render_report @profiles, :action => :grouped_itinerary
  end
  
  def custom_itinerary_report
    @travel_segments = if params[:include_old] != 'true' then
        TravelSegment.current
      else
        TravelSegment.find(:all)
      end

    @travel_segments.sort!
  end 
  
  def custom_itinerary
    travel_segment
  end
  
  def show_custom_itinerary_report
    puts params.inspect
  end
  
  def  filter_travel_segments
    custom_itinerary_report
  
    @travel_segments = TravelSegment.filter(@travel_segments, params)
    
    render  :partial  => 'ts_filter_list', 
            :locals   => { :sortable => true, :prefix => '' },
            :object   => @travel_segments
  end
  
  def manual_donations
    @columns = MyOrderedHash.new( [
      :last_name, 'string',
      :first_name, 'string',
      :project, 'string',
      :created_at, 'string',
      :type, 'string',
      :orig_amount, 'currency',
      :rate, 'string',
      :cad_amount, 'currency',
      :status, 'string'
    ] )

    projects = Project.find @projects_ids,
                 :include => :profiles,
                 :select => "#{Profile.table_name}.motivation_code"
    motivation_codes = projects.collect{ |p|
                      p.profiles.collect(&:motivation_code)
                    }.flatten.reject{ |mc| mc == '0' }

    conditions_str = ""; conditions_var = []
    if params[:type] && params[:type] != 'all'
      type = DonationType.find_by_description params[:type]
      if type
        conditions_str += "donation_type_id = ?" if params[:type]
        conditions_var << type.id
      end
    end
    if params[:status] && params[:status] != 'any' && type && type.description == 'USDMANUAL'
      conditions_str += " AND status = ?"
      conditions_var << params[:status]
    end

    donations = ManualDonation.find_all_by_motivation_code motivation_codes, 
                   :include => :donation_type_obj,
                   :conditions => [ conditions_str, *conditions_var ]

    @rows = []
    loop_reports_viewers(@projects_ids, @include_pref1_applns) do |ac,a,v,p|
      for d in donations.find_all{ |d| d.motivation_code == ac.motivation_code }
        @rows << [ p.last_name, p.first_name, ac.project.title,
                   d.created_at, d.donation_type, d.original_amount_display, 
                   d.conversion_rate_display, d.amount, d.status ]
      end
    end

    @page_title = "Manual Donations #{@projects.collect(&:title).join(',')}"

    render_report @rows
  end

  def prep_items
    # at this point we are guaranteed to have @projects and @prep_items set as
    # arrays of projects and prep_items, respectively
    @page_title = "Prep Items for " + if @projects.size == @eg.projects.size then
        "All Projects"
      elsif @projects.size == 1
        @projects[0].title
      else
        "Various Projects"
      end

    columns_arr = [
      :name, 'string',
      :project, 'string'
    ]

    if params[:prep_item_id] && params[:prep_item_id] != 'all'
      @prep_items = [ PrepItem.find(params[:prep_item_id]) ]
    end

    # ensure profile_prep_items is current
    prep_item_applicable_profiles = Hash[@prep_items.collect{ |prep_item| [ prep_item, prep_item.applicable_profiles(@project) ] }]
    @prep_items.delete_if{ |prep_item| prep_item_applicable_profiles[prep_item].empty? }
    @profiles = Profile.find(:all, 
      :include => :received_prep_items, 
      :conditions => { :project_id => @projects.collect(&:id), :id => prep_item_applicable_profiles.values.flatten.collect(&:id)
    })
    @participants = []
    
    i = 1
    for prep_item in @prep_items
      if prep_item.paperwork
        columns_arr += [ "#{prep_item.title}#{" (sub#{i})" if csv_requested}", 'string']
        columns_arr += [ "(rec#{i})", 'string' ] if csv_requested
      else
        columns_arr += [ "#{prep_item.title}#{" (done#{i})" if csv_requested}", 'string']
        columns_arr += [ " ", 'string' ] if csv_requested
      end
      i += 1
    end
   
    @columns = MyOrderedHash.new columns_arr

    for profile in @profiles
      row = []
      if profile.class == StaffProfile
        name = "(staff) #{profile.viewer.try(:name)}"
      else
        name = profile.viewer.name
      end
      row += [ name, profile.project.name ]

      for prep_item in @prep_items
        if prep_item.can_be_assigned(profile)
          profile_prep_item = profile.profile_prep_items.find_or_create_by_prep_item_id(prep_item.id)

          if prep_item.paperwork
            if profile_prep_item.completed_at
              row << (csv_requested ? "Y" : "<p class='prep_items_submitted_column'>[&#x2713;]</p>")
            else
              row << (csv_requested ? "n" : "<p class='prep_items_submitted_column'>[&nbsp;]</p>")
            end
          else
            if profile_prep_item.completed_at
              row << (csv_requested ? "Y" : "<p class='prep_items_todo_column'>[&#x2713;]</p>")
            else
              row << (csv_requested ? "n" : "<p class='prep_items_todo_column'>[&nbsp;]</p>")
            end
          end

          if prep_item.paperwork && profile_prep_item.received_at
            row << (csv_requested ? "Y" : "<p class='prep_items_received_column'>[&#x2713;]</p>")
          elsif prep_item.paperwork && !profile_prep_item.received_at
            row << (csv_requested ? "n" : "<p class='prep_items_received_column'>[&nbsp;]</p>")
          else
            row << (csv_requested ? " " : "&nbsp;")
          end
        else
          row += [ csv_requested ? "" : "&nbsp" ] * 2
        end
      end

      @participants << row
    end

    render_report @participants
  end
  
  def changed_always_editable_answer_after_date
    cutoff_date = DateParamsParser.parse(params, "date")
    @columns = MyOrderedHash.new([
      :name, 'string',
      :project, 'string',
      'full application', 'string',
      'summary', 'string',
      "what's changed", 'string',
    ])
    @page_title = "Applications with always editable fields that have been changed on or after #{cutoff_date}"

    # approach here is to get all elements that are in the always editable form, then search for answers on them
    # based on updated_at
    
    @always_editable_elements = []
    @eg.forms.collect(&:questionnaire).each do |q|
      q.filter = { :filter => [ "always_editable" ], :default => false }
      @always_editable_elements << q.pages.collect(&:elements_flattened).flatten
    end
    @always_editable_elements.flatten!

    @rows = []
    answers = Answer.find(:all, :conditions => [ "question_id in (0, ?) AND updated_at >= ?",
                               @always_editable_elements.collect(&:id), cutoff_date ] )
    instance_ids = answers.collect(&:instance_id)
    instance_ids_to_answers = answers.group_by(&:instance_id)

    # include applns that have a person whose emergency contact or personal info element has updated
    person_attributes_changed_ids = []
    emerg_attributes_changed_ids = []
    Appln.find_all_by_form_id(@eg.forms.collect(&:id)).each do |app|
      p = app.try(:viewer).try(:person)
      next unless p
      if (p.updated_at && p.updated_at > cutoff_date) || 
        (p.person_extra.try(:updated_at) && p.person_extra.try(:updated_at) > cutoff_date)
        person_attributes_changed_ids << app.id
        instance_ids << app.id
      end
      if (p.emerg.try(:updated_at) && p.emerg.try(:updated_at) > cutoff_date)
        emerg_attributes_changed_ids << app.id
        instance_ids << app.id
      end
    end
    instance_ids.uniq!

    # extract the results to a hash then build the html
    Appln.find_all_by_id(instance_ids, :include => :profiles).each do |app|
      app.profiles.each do |profile|
        next unless profile.is_a?(Acceptance) && @projects.include?(profile.project)
        elements = (instance_ids_to_answers[app.id] || []).collect{ |ans| { :answer => ans, :element => ans.element, :instance => app } }
        person_attributes = {}
        if person_attributes_changed_ids.include?(app.id)
          changed_hash = {}
          changed_hash.merge!(app.viewer.person.changed_since_hash(cutoff_date))
          changed_hash.merge!(app.viewer.person.person_extra.changed_since_hash(cutoff_date))
          person = profile.viewer.try(:person)
          person_attributes = changed_hash.collect{ |att, val| changed_always_editable_follow_foreigns(att, val, person) }
        end
        emerg_attributes = {}
        if emerg_attributes_changed_ids.include?(app.id)
          emerg = app.viewer.person.emerg
          changed_hash = emerg.changed_since_hash(cutoff_date)
          #emerg_attributes = changed_hash.collect{ |att, val| { :txt => att, :answer => val } }
          emerg_attributes = changed_hash.collect{ |att, val| changed_always_editable_follow_foreigns(att, val, emerg) }
        end

        next unless elements.present? || person_attributes.present? || emerg_attributes.present?
        
        elements_block = render_to_string(:partial => 'combined_changed_list', :locals => { :elements => elements,
                               :person_attributes => person_attributes, :emerg_attributes => emerg_attributes })
        if params[:format] == 'csv'
          summary_url = summary_profiles_viewer_url(profile)
          entire_url = entire_profiles_viewer_url(profile)
        else
          summary_url = "<A HREF=\"#{summary_profiles_viewer_path(profile)}\" target=\"_blank\">summary</A>"
          entire_url = "<A HREF=\"#{entire_profiles_viewer_path(profile)}\" target=\"_blank\">entire</A>"
        end

        @rows << [ app.try(:viewer).try(:person).try(:full_name), app.profile.try(:project).try(:name), 
          summary_url, entire_url, elements_block ]
      end
    end

    render_report @rows
  end
  
  protected
  
  def changed_always_editable_follow_foreigns(att, val, model)
    # Try to follow foreign keys, like person_local_province_id should follow person_local_province.name
    # If the object resolves to a String, use that, otherwise try sending .name
    if att =~ /(.*)_id/
      ref = $1
      if model && model.respond_to?(ref)
        element_txt = ref
        obj = model.send(ref)
        if obj.nil?
          answer_txt = ""
        elsif obj.is_a?(String)
          answer_txt = obj
        elsif obj.respond_to?(:name)
          answer_txt = obj.name
        else
          answer_txt = val
        end
      else
        element_txt = att
        answer_txt = val
      end
    else
      element_txt = att
      answer_txt = val
    end

    { :txt => element_txt, :answer => answer_txt } 
  end

  def csv_requested
    [ 'csv', 'excel (csv)' ].include? params[:format]
  end

  def try_to_delete_invalid_apps
    Appln.delete_those_with_invalid_viewers
  end

  def get_passport_info(ac, p, a, ec_entry)
    if ec_entry
        PassportInfo.new(ec_entry.emerg_passportNum,
          ec_entry.emerg_passportExpiry,
          ec_entry.emerg_passportOrigin)
    else
      PassportInfo.new('', '', '')
    end
  end

 # helper for all the reports, handles the rendering to csv or html
  def render_report(rows, params2 = {})
    params2[:action] ||= params[:action]
    @pdf = true if params[:format] == 'pdf'

    # this should use respond_to eventually, I can't get it to work right now though
    # so I'll do it the old-fashioned way    
    if csv_requested
      now = Time.now.strftime("%A %B %d %Y")
      filename = @page_title || @filename || params[:action]
      filename.gsub!('  ', ' ')
      
      headers['Content-Type'] = "text/csv"
      headers['Content-Disposition'] = "attachment; filename=\"#{filename}.csv\""
      headers['Cache-Control'] = ''
      
      csv_title = "#{filename} generated #{now}"#.gsub(' ',',')
      @title = csv_title

      csv_template = "#{params2[:action]}_csv.rhtml"
      if FileTest.exists?("app/views/reports/#{csv_template}")
        render :action => csv_template, :layout => false
      else
        render :inline => to_csv(csv_title, @columns, rows)
      end
    else
      @sortable = params2[:sortable].nil? ? true : params2[:sortable] 
      
      render :action => params2[:action], :layout => @@reports_layout
    end
  end
  
  # grabs the columns specified from the values, in the order given in columns
  def get_rows(values, columns)
    columns = columns.collect { |c| c.class == Array ? c[0] : c }
    values.collect { |v|
      columns.collect { |c|
        v[c.to_s]
      }
    }
  end
  
  # Returns a columns ordered hash (which is then used in the javascript sorting)
  # by using the type info in the db already
  # 
  # Format for columns is array of either model_column_name which uses the same name in the report
  #   or [ model_column_name, report_column_name ]
  # 
  # Example: columns = [ 'donor_name', [ 'donation_type', 'type' ], 'amount' ]
  #       then the report will have donor_name, type, amount as its column names, with the 
  #       appropriate value
  #       
  # Filters by taking only the columns in columns
  def columns_from_model(model, columns)
    model_columns = columns.collect { |c| c.class == Array ? c.first : c }
    model_columns_to_report_columns = columns.collect { |c| c.class == Array ? c : [ c, c ] }
    report_columns = model_columns_to_report_columns.collect{ |c| c.second }
    
    MyOrderedHash.new( model.columns.collect { |c|
      if model_columns.include? c.name
        [ model_columns_to_report_columns.assoc(c.name.to_s)[1], c.type.to_s ]
      else nil
      end
    }.compact.sort { |a,b| # at this point each entry is an array [ name, type ]
      report_columns.index(a[0].to_s) <=> report_columns.index(b[0].to_s)
    }.flatten )
  end
  
  # refactored out so that cm2007 can use this registrants list and take only those applying to cm2007
  # 
  def registrants_only
    @columns = MyOrderedHash.new( [
      :last_name, 'string', 
      :first_name, 'string',
      :gender, 'string',
      @eg.has_your_campuses ? [ :campus, 'string' ] : nil,
      @eg.has_your_campuses ? [ :year, 'int' ] : nil,
      :status, 'string',
      :pref1, 'string',
      :pref2, 'string',
      :accepted, 'string',
      :phone, 'string',
      :email, 'string'
    ].flatten.compact )
    @rows = [ ]
    
    Viewer.find(:all, :include => :persons).each do |v|
      p = v.person
      if !v.is_student?(@eg) || p.nil?
        next
      end
      @as = v.applns.find(:all, :include => :form)
      @as.reject! { |a| a.form.event_group_id.nil? || a.form.event_group_id != @eg.id }

      next if @as.empty?
      @a = @as[0]
      
      p1 = (@a && @a.preference1) ? @a.preference1.title : ''
      p2 = (@a && @a.preference2) ? @a.preference2.title : ''
      
      accepts = @a.nil? ? nil : Acceptance.find_all_by_appln_id(@a.id)
      @acceptance_obj = accepts.nil? ? nil : accepts.find { |acc| acc.project.event_group_id == @eg.id }
      acceptance = @acceptance_obj ? @acceptance_obj.project.title : ''
      
      if !( (@a && @a.preference1_id && @projects_ids.include?(@a.preference1_id)) || 
       (@acceptance_obj && @projects_ids.include?(@acceptance_obj.project_id)))
        next
      end
      
      status = @a.nil? ? "has_account" : @a.status
      
      gender = p.gender
      
      registrant = Registrant.new(p.preferred_last_name, p.preferred_first_name, gender,
                                  (if !@eg.has_your_campuses then :skip elsif p.campuses[0] then p.campuses[0].campus_shortDesc else '' end), 
                                  (if !@eg.has_your_campuses then :skip elsif p.campuses[0] then p.person_year.year_in_school.year_desc else '' end),
      status, p1, p2, acceptance, p.person_local_phone, p.person_email)
      
      if block_given?
        yield v, @a, registrant
      end
      
      @rows << registrant
    end
  end
  
  def emergency_contact_columns(prefix)
    MyOrderedHash.new [
    :"#{prefix}name", 'string', 
    :"#{prefix}relation", 'string', 
    :"#{prefix}home_number", 'string', 
    :"#{prefix}work_number", 'string', 
    :"#{prefix}cell_number", 'string',
    :"#{prefix}email", 'string'
    ]
  end
  
  def emergency_contact(prefix, instance)
    prefix = prefix.to_s
    
    EmergencyContact.new(
                         extract_form_answer(:"emergency_contact_#{prefix}_name", instance),
    extract_form_answer(:"emergency_contact_#{prefix}_relationship", instance),
    extract_form_answer(:"emergency_contact_#{prefix}_home_phone", instance),
    extract_form_answer(:"emergency_contact_#{prefix}_work_phone", instance),
    extract_form_answer(:"emergency_contact_#{prefix}_cell_phone", instance),
    extract_form_answer(:"emergency_contact_#{prefix}_email", instance)
    )
  end
  
  def set_permissions_level
    @is_staff = !@viewer.is_student?(@eg)
    @is_eventgroup_coordinator = @viewer.is_eventgroup_coordinator?(@eg)
    true
  end
  
  def ensure_is_general_staff
    render(:inline => 'Must be staff') unless @is_staff
  end

  def ensure_is_eventgroup_coordinator
    render(:inline => 'Must be eventgroup coordinator') unless @is_eventgroup_coordinator
  end
  
  @@reports_layout = 'report'
  
 # @@year_eg_id = (EventGroup.find_by_title('2007') || EventGroup.find(:first)).id.to_i
 	
  @@form_elements = { 2 => {  # 2007 Campus Ministry Projects
      :title => 7,
      :first_name => 9,
      :middle_name => 10,
      :last_name => 11,
      :curr_province => 23,
      :perm_province => 35,
      :phone => 26,
      :cell => 27,
      :campus_year => 91, 
      :leadership_rating => 592, 
      :leadership_a => 593, 
      :leadership_b => 594, 
      :leadership_c => 595, 
      :training_rating => 596, 
      :training_a => 597,
      :training_b => 598,
      :training_c => 599,
      :birthdate => 12,
      :passport_number => 84,
      :passport_country_origin => 83,
      :passport_expiry => 85,
      :attending_cm => 101,
      :cm_travel_with_group => 102,
      :cm_plans => 103,
      :travel_request_notes => 119,
      :departure_city => 106,
      :departure_other => 117,
      :emergency_contact_1_name => 47,
      :emergency_contact_1_relationship => 48,
      :emergency_contact_1_home_phone => 49,
      :emergency_contact_1_work_phone => 50,
      :emergency_contact_1_cell_phone => 51,
      :emergency_contact_1_email => 52,
      :emergency_contact_2_name => 55,
      :emergency_contact_2_relationship => 56,
      :emergency_contact_2_home_phone => 57,
      :emergency_contact_2_work_phone => 58,
      :emergency_contact_2_cell_phone => 59,
      :emergency_contact_2_email_phone => 60,
      :emergency_conditions => 69,
      :emergency_conditions_description => 70,
      :emergency_medication_needed => 71,
      :emergency_medication_with => 72,
    }, 3 => {
      :campus_year => 727,
      :phone => 661,
      :cell => 662,
      :leadership_rating => 1234, 
      :leadership_a => 1235, 
      :leadership_b => 1236, 
      :leadership_c => 1237, 
      :training_rating => 1238, 
      :training_a => 1239,
      :training_b => 1240,
      :training_c => 1241,
      :training_d => 1242,
    }, 21 => {
      :phone => 6621,
      :cell => 6622,
    },
      6 => {
      :title => 1357,
      :first_name => 1359,
      :middle_name => 1360,
      :last_name => 1361,
      :curr_province => 1373,
      :perm_province => 1385,
      :phone => 1376,
      :cell => 1377,
      :campus_year => 91, 
      :leadership_rating => 1234, 
      :leadership_a => 1235, 
      :leadership_b => 1236, 
      :leadership_c => 1237, 
      :training_rating => 1238, 
      :training_a => 1239,
      :training_b => 1240,
      :training_c => 1241,
      :training_d => 1242,
      :birthdate => 1362,
      :passport_number => 1435,
      :passport_country_origin => 1434,
      :passport_expiry => 1436,
      :attending_cm => 101,
      :cm_travel_with_group => 102,
      :cm_plans => 103,
      :travel_request_notes => 119,
      :departure_city => 106,
      :departure_other => 117,
      :emergency_contact_1_name => 1398,
      :emergency_contact_1_relationship => 1399,
      :emergency_contact_1_home_phone => 1400,
      :emergency_contact_1_work_phone => 1401,
      :emergency_contact_1_cell_phone => 1402,
      :emergency_contact_1_email => 1403,
      :emergency_contact_2_name => 1406,
      :emergency_contact_2_relationship => 1407,
      :emergency_contact_2_home_phone => 1408,
      :emergency_contact_2_work_phone => 1409,
      :emergency_contact_2_cell_phone => 1410,
      :emergency_contact_2_email_phone => 1411,
      :emergency_conditions => 1420,
      :emergency_conditions_description => 1421,
      :emergency_medication_needed => 1422,
      :emergency_medication_with => 1423,
    } }
  
  # adds any nested elements from @@form_elements
  def ReportsController.include_nested_elements(elements, eg_id)
    elements.each do |e|
      @@form_elements[eg_id][e.id] = e.id
      
      # add any sub-elements
      if !e.elements.empty?
        include_nested_elements e.elements
      end
    end
  end
  begin
    # TODO: eventually we'll have to go over all event group ids..
    include_nested_elements(Element.find(@@form_elements[@@year_eg_id].values))
  rescue
  end
  
  def bool_to_yesno(v)
    v == '1' ? 'Yes' : 'No'
  end
  
  def element(form)
  end
  
  def extract_form_question_and_answer(element_symbol, instance)
    e = get_element @@form_elements[@eg.id][element_symbol]
    e.text + ": " + get_displayable_answer(e, instance)
  end
  
  def extract_form_answer(element_symbol, instance)
    e = get_element @@form_elements[@eg.id][element_symbol]
    get_displayable_answer e, instance
  end
  
  def get_displayable_answer(element, instance)
    params = if @answers_cache && !@answers_cache.empty?
      { :cache => @answers_cache, :use_cache_only => true }
    else {} end
    answer = element.get_answer(instance, params) || '' if element
    
    if element.class == YesNo
      answer = bool_to_yesno(answer)
    elsif element.class == Group
      element.elements.each do |e|
        answer += ' ' + get_displayable_answer(e, instance)
      end
    elsif element.class == Multicheckbox
      element.elements.each do |e|
        a = e.get_answer(instance, params)
        answer += e.text if a == "true" || a == "1"
      end
    end
    
    answer.to_s
  end
  
  def get_element(id)
    @element_cache ||= {}
    begin
      @element_cache[id] || @element_cache[id] = Element.find(id)
    rescue
      nil
    end
  end
  
  def set_title
    @page_title = "Reports"
    @submenu_title = "Standard Reports"
  end
  
  def set_projects
    requested_projects = (params[:project_id] == 'all' || !params[:project_id]) ? 
        @eg.projects : @eg.projects.find(params[:project_id].split(','))
    
    @include_pref1_applns = params[:include_pref1s]
    
    @projects = []
    requested_projects.each do |project|
      # ensure the user has permission to access this project
      @viewer.set_project project
      if @viewer.is_eventgroup_coordinator?(@eg) || @viewer.is_project_director? || 
        @viewer.is_project_administrator? || @viewer.is_project_staff?
        @projects << project
      end
    end
    
    if @projects.size == 1
      @project_title = @projects[0].title
    else
      @project_title = ''
    end
    @projects_ids = @projects.collect{ |p| p.id }
    @many_projects = @projects_ids.size > 1
    true
  end
  
  def set_travel_segment
    if params[:ts]
      @travel_segments = TravelSegment.find params[:ts].keys
    elsif params[:travel_segment_id] == 'all'
      @travel_segments = TravelSegment.find_all_by_event_group_id @eg.id
    else
      @travel_segments = [ TravelSegment.find(params[:travel_segment_id]) ]
    end
  end
  
  def set_cost_items
    @cost_items = if params[:cost_item_id] == 'all' then
      CostItem.find :all
    else
      CostItem.find params[:cost_item_id].split(',')
    end
  end

  def set_prep_items
    @prep_items = (@projects.collect(&:prep_items) + @eg.prep_items.find_all_by_individual(true)).flatten.compact.uniq
  end

  def set_viewer
    @report_viewer ||= Viewer.find params[:viewer_id]
  end

  def to_csv(report_info, headers, rows)
    # add the report info
    csv = report_info + "\r\n\r\n"
    
    # table headers
    csv += headers.keys.collect { |k| k.to_s }.join ','
    csv += "\r\n"
    
    # values
    csv += rows.inject('') do |csv, row|
      
      formatted_vals = []
      row.to_a.each_with_index do |v,i|
        formatted_vals << values(v, headers[i])
      end
      formatted_vals.flatten!
      formatted_vals = formatted_vals.collect { |fv| '"' + fv.to_s.gsub('"', '""') + '"' }
      csv + formatted_vals.join(',') + "\r\n"
    end
    
    csv
  end
  
  def values(o, header)
    if header == 'currency'
      "%0.2f" % v.to_f
    elsif o.respond_to?('values')
      o.values
    else
      o
    end
  end
  
  def set_skip_title
    @skip_title = request.xml_http_request?
    true
  end
  
end
