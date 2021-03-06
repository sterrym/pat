class SpApplicationMailer < ActionMailer::Base
  def render_from_email(type)
    body render(:inline => @eg.reference_emails.find_by_email_type(type).text, :body => @body)
  end
  
  def accepted(acceptance, processor_email)
    setup(acceptance.appln)
    @subject = 'Your Application has been Accepted'
    @body[:project] = acceptance.project.title
    @body[:support_coach] = (acceptance.support_coach_str == acceptance.support_coach_none) ?
             nil : acceptance.support_coach_str
    @body[:applied_as_intern] = acceptance.appln.as_intern?
    @body[:accepted_as_intern] = acceptance.as_intern?
    @body[:applied_as_team_leader] = acceptance.appln.as_team_leader?
    @body[:accepted_as_team_leader] = acceptance.as_team_leader?
    @bcc = processor_email
    render_from_email 'app_accepted'
  end
  
  def profile_accepted(acceptance, email)
    setup(acceptance.appln)
    @subject = 'An applicant has been accepted'
    @body[:email] = email
    @recipients = acceptance.project.project_directors.collect(&:viewer).collect(&:email)
    render_from_email 'profile_accepted'
  end

  def submitted(app)
    setup(app)
    @subject = 'Your Application has been Received'
    render_from_email 'app_submitted'
  end
  
  def completed(app)
    setup(app)
    @subject = 'Your Application is Ready for Evaluation'
    render_from_email 'app_completed'
  end
  
  def withdrawn_notification(profile, recipients)
    setup(profile.appln)
    @subject = 'Application has been Withdrawn'
    @body[:profile] = profile
    @recipients = recipients

    render_from_email 'app_withdrawn_notify'
  end

  def withdrawn(app)
    setup(app)
    @subject = 'Application has been Withdrawn'
    render_from_email 'app_withdrawn'
  end
  
  def unsubmitted(app)
    setup(app)
    @subject = 'Your Application is now Incomplete'
    content_type "text/html"
    render_from_email 'app_unsubmitted'
  end
  
  protected
    def setup(app)
      @eg = app.form.event_group
      @name = app.viewer.name
      @recipients = "#{@name} <#{app.viewer.email}>"
      eg = app.profile.project ? app.profile.project.event_group : app.form.event_group
      @from = eg.outgoing_email.to_s.empty? ? $sp_email : eg.outgoing_email
      @body = {:applicant_name => app.viewer.name,
               :applicant_email => app.viewer.email,
               :applicant_phone => app.viewer.phone }
      content_type "text/html"
    end
end
