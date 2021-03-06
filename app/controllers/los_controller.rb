class LosController < ApplicationController
  before_filter :authenticate_user!, :except => [:showEvaluationsRepresentation]
  before_filter :authenticate_user_or_session_token, :only => [:showEvaluationsRepresentation]
  before_filter :filterLanguage, :only => [:create, :update]
  before_filter :getLoForUsersOrApps, :only => [:showEvaluationsRepresentation]

  # GET /los
  # GET /los.json
  def index
    @los = Lo.all(:order => 'name ASC')
    authorize! :index, @los

    Utils.update_sessions_paths(session, request.url, nil)
    
    @options_select = getOptionsForSelect
    respond_to do |format|
      format.html
      format.json { render json: @los.map{ |lo| lo.extended_attributes } }
    end
  end

  def publicIndex
    @los = Lo.Public.order('created_at DESC')
    authorize! :rshow, @los

    @options_select = getOptionsForSelect
    respond_to do |format|
      format.html
      format.json { render json: @los }
    end
  end

  def rankedIndex
    @los = Lo.all
    authorize! :index, @los

    @metrics = Metric.allc

    if @metrics.length > 0
      @los = Lo.orderByScore(@los,@metrics[0])
    end

    respond_to do |format|
      format.html
      format.json {
        render json: @los.map{ |lo| lo.extended_attributes } 
      }
    end
  end

  # GET /los/1
  # GET /los/1.json
  def show
    unless current_user.isAdmin?
      redirect_to "/rlos/" + params[:id]
      return
    end
    
    @lo = Lo.find(params[:id])
    authorize! :show, @lo

    @assignments = @lo.assignments.sort{|b,a| a.compareAssignmentForAdmins(b)}
    authorize! :index, @assignments

    @evaluations = @lo.evaluations.allc.sort_by{ |ev| [ev.evmethod.name,ev.updated_at]}
    authorize! :index, @evaluations
    
    @scores = @lo.scoresc.sort_by{|s| [s.metric.evmethods.sort_by{|ev| ev.name}.first.name,s.metric.name]}

    @evmethods = @lo.evmethods.uniq.sort_by{|ev| ev.name}

    Utils.update_sessions_paths(session, los_path, request.url)
    @options_select = getOptionsForSelect
    respond_to do |format|
      format.html
      format.xlsx {
        render :xlsx => "show", :filename => "LO" + @lo.id.to_s + ".xlsx", :type => "application/vnd.openxmlformates-officedocument.spreadsheetml.sheet"
      }
      format.json { 
        render json: @lo.extended_attributes
      }
    end
  end

  #Reviewer show
  def rshow
    user = view_as_user

    @lo = Lo.find(params[:id])
    authorize! :rshow, @lo

    unless user.role?("Admin")
      @assignments = @lo.assignments.where(:user_id => user.id, :status => "Pending")
    else
      @assignments = @lo.assignments
    end
    authorize! :rshow, @assignments
    
    @evmethods = Evmethod.allc.select{|ev| can?(:evaluate, @lo, ev) }
    unless user.role?("Admin")
      @evmethods = @evmethods.reject{|ev| ev.automatic? }
    end

    unless user.role?("Admin")
      @evaluations = user.evaluations.where(:lo_id=>@lo.id).allc
      authorize! :rshow, @evaluations
    else
      @evaluations = @lo.evaluations.allc
      authorize! :show, @evaluations
    end
    @evaluations = @evaluations.sort_by{ |ev| ev.updated_at}.reverse

    #After reject -> after destroy dependence
    Utils.update_sessions_paths(session, nil, request.url)
    
    @options_select = getOptionsForSelect
    respond_to do |format|
      format.html
      format.json { render json: @lo }
    end
  end

  def show_metadata
    lo = Lo.find(params[:id])
    authorize! :show, lo

    respond_to do |format|
      format.any {
        unless lo.nil? or lo.getMetadata({:format => "json", :schema => Metadata::Lom.schema}).blank?
          xmlMetadata = lo.getMetadata({:format => "xml", :schema => Metadata::Lom.schema})
        else
          xmlMetadata = Metadata.getEmptyXml
        end
        render :xml => xmlMetadata, :content_type => "text/xml"
      }
    end
  end

  # GET /los/new
  # GET /los/new.json
  def new
    @lo = Lo.new
    authorize! :create, @lo

    Utils.update_return_to(session,request)
    @options_select = getOptionsForSelect
    respond_to do |format|
      format.html
      format.json { render json: @lo.extended_attributes }
    end
  end

  # GET /los/1/edit
  def edit
    @lo = Lo.find(params[:id])
    authorize! :edit, @lo

    Utils.update_return_to(session,request)
    @options_select = getOptionsForSelect
    respond_to do |format|
      format.html
      format.json { render json: @lo.extended_attributes }
    end
  end

  # POST /los
  # POST /los.json
  def create
    @lo = Lo.new(params[:lo])
    @lo.owner_id = current_user.id
    authorize! :create, @lo

    @options_select = getOptionsForSelect

    respond_to do |format|
      if @lo.save 
        format.html { redirect_to lo_path(@lo), notice: I18n.t("los.message.success.create") }
        format.json { render json: @lo.extended_attributes, status: :created, location: @lo }
      else
        format.html { 
          flash.now[:alert] = @lo.errors.full_messages
          render action: "new"
        }
        format.json { render json: @lo.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /los/1
  # PUT /los/1.json
  def update
    @lo = Lo.find(params[:id])
    authorize! :update, @lo

    @options_select = getOptionsForSelect

    respond_to do |format|
      if @lo.update_attributes(params[:lo])
        format.html { redirect_to Utils.return_after_create_or_update(session), notice: I18n.t("los.message.success.update") }
        format.json { head @lo.extended_attributes }
      else
        format.html { 
          flash.now[:alert] = @lo.errors.full_messages
          render action: "edit"
        }
        format.json { render json: @lo.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /los/1
  # DELETE /los/1.json
  def destroy
    @lo = Lo.find(params[:id])
    authorize! :destroy, @lo
    @lo.destroy

    respond_to do |format|
      format.html { redirect_to home_path, notice: I18n.t("los.message.success.delete") }
      format.json { head :no_content }
    end
  end

  def removelist
    @los = Lo.find(params[:lo_ids].split(","));
    authorize! :destroy, @los

    @los.each do |lo|
      lo.destroy
    end

    respond_to do |format|
      format.html { redirect_to(:back) }
      format.json { head :no_content }
    end
  end

  #Stats
  def stats
    @los = Lo.find(params[:lo_ids].split(","));
    getStatsForLos(@los)
  end

  def getStatsForLos(los)
    @los = los
    authorize! :show, @los

    #Get the average score
    @scores = []
    Metric.allc.each do |m|
      metricScores = @los.map{|lo| lo.scores.select{|s| s.metric_id==m.id}}.map{|sA| sA.first}

      if metricScores.empty? or !metricScores.select{|ms| ms.nil? }.empty?
        #To get stats from a set of LOs all of them should have been evaluated
        next
      end

      #Calculate average value
      sum = 0
      metricScores.map{|mS| sum = sum + mS.value}
      average = sum.to_f/metricScores.size

      score = Score.new
      score.metric_id = m.id
      score.value = average
      @scores << score
    end

    @evmethods = []
    @los.each do |lo|
      if lo.getScoreEvmethods.empty?
        @evmethods = []
        break
      end
      @evmethods = @evmethods + lo.getScoreEvmethods
    end
    @evmethods.uniq!
  end

  #Compare
  def compare
    @los = Lo.find(params[:lo_ids].split(","));
    authorize! :show, @los

    @metrics = Metric.allc

    if @metrics.length > 0
      @los = Lo.orderByScore(@los,@metrics[0])
    end
    
    @evmethods = []
    @los.each do |lo|
      if lo.getScoreEvmethods.empty?
        @evmethods = []
        break
      end
      @evmethods = @evmethods + lo.getScoreEvmethods
    end
    @evmethods.uniq!
  end

  #Search
  def searchIndex
    @evmethods = Evmethod.allc
    render 'search'
  end

  def search
    @params = params
    @evmethods = Evmethod.allc

    #Search Logic
    #Params Example
    # {"utf8"=>"✓",
    # "authenticity_token"=>"hDBVxA7HIBZ3lGGY1vVx/M7OBWUCKfWnUJzbx0FiSus=",
    # "query"=>"QUERY",
    # "repository"=>"REPOSITORY",
    # "hasText"=>"1",
    # "hasImages"=>"1",
    # "hasVideos"=>"1",
    # "hasAudios"=>"1",
    # "hasQuizzes"=>"1",
    # "hasWebs"=>"1",
    # "hasFlashObjects"=>"1",
    # "hasApplets"=>"1",
    # "hasDocuments"=>"1",
    # "hasFlashcards"=>"1",
    # "hasVirtualTours"=>"1",
    # "hasEnrichedVideos"=>"1",
    # "evmethods_yes"=>["1", "2"],
    # "evmethods_no"=>["1", "2"],
    # "queryStatement"=>"1",
    # "controller"=>"los",
    # "action"=>"search"}

    #Perform Search based on query param and parameters
    #TODO: Enhance with sphinx
   
    queries = []

    unless params["query"].blank?
      if params["queryStatement"] == "1" and can?(:performQueryStatements, nil)
        queries << params["query"]
      else
        queries << "los.name LIKE '%" + params["query"] + "%'"
      end
    end

    #Repository
    if !params["repository"].blank?
      queries << "los.repository='" + params["repository"] + "'"
    end

    if params["hasText"] == "1"
      queries << "los.hasText=true"
    end

    if params["hasImages"] == "1"
      queries << "los.hasImages=true"
    end

    if params["hasVideos"] == "1"
      queries << "los.hasVideos=true"
    end

    if params["hasAudios"] == "1"
      queries << "los.hasAudios=true"
    end

    if params["hasQuizzes"] == "1"
      queries << "los.hasQuizzes=true"
    end

    if params["hasWebs"] == "1"
      queries << "los.hasWebs=true"
    end

    if params["hasFlashObjects"] == "1"
      queries << "los.hasFlashObjects=true"
    end

    if params["hasApplets"] == "1"
      queries << "los.hasApplets=true"
    end

    if params["hasDocuments"] == "1"
      queries << "los.hasDocuments=true"
    end

    if params["hasFlashcards"] == "1"
      queries << "los.hasFlashcards=true"
    end

    if params["hasVirtualTours"] == "1"
      queries << "los.hasVirtualTours=true"
    end

    if params["hasEnrichedVideos"] == "1"
      queries << "los.hasEnrichedVideos=true"
    end

    query = Utils.composeQuery(queries)

    #Include query in the search form
    if params["queryStatement"] == "1" and can?(:performQueryStatements, nil)
      @params["query"] = query
    end
    
    if !query.nil?
      begin
        @los = Lo.where(query)
        #This line will raise an exception, if the SQL Statement is invalid
        @los.exists?
      rescue Exception => e
        @los = []
        flash.now[:alert] = e.message
      end
    else
      @los = Lo.all
    end

    #Filter by evaluations

    #Evaluated
    if !params["evmethods_yes"].blank?
      Evmethod.find(params["evmethods_yes"]).each do |evmethod|
        @los = @los.select{|lo| lo.hasBeenEvaluatedWithEvmethod(evmethod)}
      end
    end

    #Non evaluated
    if !params["evmethods_no"].blank?
      Evmethod.find(params["evmethods_no"]).each do |evmethod|
        @los = @los.select{|lo| !lo.hasBeenEvaluatedWithEvmethod(evmethod)}
      end
    end

    authorize! :show, @los
  end

  def download
    los = Lo.find(params[:lo_ids].split(",").map{|id| id.to_i})
    respond_to do |format|
        format.json {
            render json: los.map{ |lo| lo.extended_attributes }, :filename => "LOs.json", :type => "application/json"
        }
        format.xlsx {
            @resources = los
            @resourceName = "LOs"
            render :xlsx => "index", :filename => "LOs.xlsx", :type => "application/vnd.openxmlformates-officedocument.spreadsheetml.sheet"
        }
    end
  end

  #Download evaluations
  def downloadevs
    @los = Lo.find(params[:lo_ids].split(",").map{|id| id.to_i})
    evaluations = @los.map{|lo| lo.evaluations.allc}.flatten.sort_by{|ev| ev.evmethod.id}
    
    respond_to do |format|
        format.json {
            render json: evaluations.map{ |ev| ev.extended_attributes }, :filename => "LOEvaluations.json", :type => "application/json"
        }
        format.xlsx {
            @resources = evaluations
            @resourceName = "LOEvaluations"
            render :xlsx => "index", :filename => "LOEvaluations.xlsx", :type => "application/vnd.openxmlformates-officedocument.spreadsheetml.sheet"
        }
    end
  end


  #Representation
  # GET /los/:id/representation?evmethods=wblts,wlbtt
  def showEvaluationsRepresentation
    authorize! :show, @lo

    @evmethods = @lo.evmethods.uniq
    unless params["evmethods"].nil?
      paramsEvmethods = params["evmethods"].split(",")
      @evmethods = (@evmethods & Evmethod.allc.select{|e| paramsEvmethods.include? e.shortname}).sort_by{|ev| paramsEvmethods.index(ev.shortname)}
    else
      @evmethods = @evmethods.sort_by{|ev| ev.name}
    end

    unless @evmethods.length > 0
      @message = I18n.t("evmethods.message.no_available")
      return render "application/embed_empty", :layout => 'embed'
    end

    if @sessionToken
      #Validate token permissions
      sessionTokenParams = {"lo" => @lo.id}
      sessionTokenParams["evmethod"] = @evmethods.first.id if @evmethods.length===1
      unless @sessionToken.is_a? SessionToken and @sessionToken.allow_to?("showchart",sessionTokenParams)
        @message = I18n.t("api.message.error.unauthorized")
        return render "application/embed_empty", :layout => 'embed'
      end
    end

    #Do not show title, only representation
    @onlyShowRepresentation = (params["showtitle"]!="true")

    respond_to do |format|
      format.html {
        render "evaluationsRepresentation", :content_type => "text/html", :layout => "embed"
      }
    end
  end


  private

  def getOptionsForSelect
    optionsForSelect = Hash.new
    optionsForSelect["lotype"] = I18n.t("los.types").map{|k,v| [v,k.to_s]}
    optionsForSelect["technology"] = I18n.t("los.technology_or_format").map{|k,v| [v,k.to_s]}
    optionsForSelect
  end

  def getOptionsForSelectFromArray(array)
    options_select = [];
    array.each do |e|
      options_select.push([e,e])
    end
    options_select
  end

  def filterLanguage
    if params[:lo] and params[:lo][:language_id] and !Utils.is_numeric?(params[:lo][:language_id])
      params[:lo].delete :language_id
    end
  end

  def view_as_user
    if current_user.role?("Admin") and params[:as_user_id]
      @represented = User.find(params[:as_user_id])
    else
      current_user
    end
  end

end
