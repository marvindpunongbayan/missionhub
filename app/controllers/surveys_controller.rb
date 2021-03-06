class SurveysController < ApplicationController
  before_filter :set_keyword_cookie, only: :start
  before_filter :prepare_for_mobile, only: [:start, :stop, :index]
  skip_before_filter :authenticate_user!
  skip_before_filter :check_url
  load_and_authorize_resource except: [:start, :stop, :index]

  require 'api_helper'
  include ApiHelper

  def index_admin
    @organization = current_person.organization_from_id(params[:org_id]) || current_organization
    authorize! :manage, @organization
    @surveys = @organization.surveys
  end

  def index
    # authenticate_user! unless params[:access_token] && params[:org_id]
    @title = "Pick A Survey"
    if current_user
      @organization = current_person.organization_from_id(params[:org_id]) || current_organization
      @surveys = @organization ? @organization.self_and_children_surveys : nil

      respond_to do |wants|
        wants.html { render 'index_admin' }
        wants.mobile
      end
    else
      return render_404
    end
  end

  def edit

  end

  def new

  end

  def destroy
    @survey.destroy
    respond_to do |wants|
      wants.html { redirect_to :back }
      wants.js {render :nothing => true}
    end
  end

  def update
    if @survey.update_attributes(params[:survey])
      redirect_to index_admin_surveys_path
    else
      render :edit
    end
  end

  def create
    @survey = current_organization.surveys.new(params[:survey])
    if @survey.save
      redirect_to index_admin_surveys_path
    else
      current_organization.surveys -= [@survey]
      render :new
    end
  end

  # Enter survey mode
  def start
    unless mhub? #|| Rails.env.test?
      redirect_to start_survey_url(@survey, host: APP_CONFIG['public_host'], port: APP_CONFIG['public_port'])
      return false
    end
    cookies[:survey_mode] = 1
    redirect_to sign_out_url(next: short_survey_url(@survey.id))
    #redirect_to short_survey_url(@survey.id)
  end

  # Exit survey mode
  def stop
    cookies[:survey_mode] = nil
    cookies[:keyword] = nil
    cookies[:survey_id] = nil
    redirect_to(request.referrer ? :back : 'http://www.missionhub.com')
  end


end
