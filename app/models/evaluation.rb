class Evaluation < ActiveRecord::Base
  attr_accessible :user_id, :assignment_id, :lo_id, :evmethod_id, :completed_at, :comments, :score,
  :item1, :item2, :item3, :item4, :item5, :item6, :item7, :item8, :item9, :item10, :item11, :item12, :item13, :item14, :item15, :item16, :item17, :item18, :item19, :item20, :item21, :item22, :item23, :item24, :item25, :item26, :item27, :item28, :item29, :item30, :item31, :item32, :item33, :item34, :item35, :item36, :item37, :item38, :item39, :item40, 
  :titem1, :titem2, :titem3, :titem4, :titem5, :titem6, :titem7, :titem8, :titem9, :titem10, :titem11, :titem12, :titem13, :titem14, :titem15, :titem16, :titem17, :titem18, :titem19, :titem20, :titem21, :titem22, :titem23, :titem24, :titem25, :titem26, :titem27, :titem28, :titem29, :titem30, :titem31, :titem32, :titem33, :titem34, :titem35, :titem36, :titem37, :titem38, :titem39, :titem40,
  :sitem1, :sitem2, :sitem3, :sitem4, :sitem5

  belongs_to :user
  belongs_to :lo
  belongs_to :evmethod
  belongs_to :assignment #optional

  validates :user_id,
  :presence => true

  validates :lo_id,
  :presence => true

  validates :evmethod_id,
  :presence => true

  validate :is_score_wrong

  def is_score_wrong
    if !self.score.nil? and !Utils.is_numeric?(self.score)
      errors.add(:score, 'The proposed overall score is not valid. Please, check it.')
    else
      true
    end
  end

  validate :duplicated_evaluation

  def duplicated_evaluation
    if self.id.nil? and !self.evmethod.allow_multiple_evaluations and !user.isAdmin?
      evaluations = Evaluation.where(:user_id => self.user.id, :lo_id => self.lo_id, :evmethod_id => self.evmethod.id)
      if evaluations.length > 0
        errors.add(:duplicated_evaluation, ": The evaluation wasn't been created because this user had already evaluated this Learning Object.")
      else
        true
      end
    else
      #No check duplicated evaluations when:
        #!self.id.nil? => Updating an existing resource
        #self.evmethod.allow_multiple_evaluations => EvMethod that allows multiple evaluations
        #user.isAdmin? => The user is an Admin...
      true
    end
  end

  after_initialize :init
  before_validation :checkScoreBeforeSave
  after_create :checkAssignment
  after_save :updateScores
  after_save :checkCallbacks

  def init
  end

  def self.allc
    Evaluation.where("evmethod_id in (?)",LOEP::Application.config.evmethods.map{|evmethod| evmethod.id})
  end
  
  def readable_completed_at
    Utils.getReadableDate(self.completed_at)
  end

  #######################
  # Get extended Evaluation Data
  #######################

  def extended_attributes
    attrs = self.attributes
    attrs["Reviewer"] = self.user.name
    attrs["loName"] = self.lo.name
    attrs["evMethodName"] = self.evmethod.name
    
    Metric.allc.select { |m| m.evmethods == [self.evmethod] }.each do |m|
      #Metrics that only use the ev method.
      #In this case, the scores of the metrics may be included in the evaluations
      if m.class.methods.include? :getScoreForEvaluation
        attrs[m.name] = m.class.getScoreForEvaluation(self)
      end
    end
    
    attrs
  end


  #Path Methods

  def evaluation_path
    evaluationModule = self.evmethod.getEvaluationModule
    helper_method_name = self.evmethod.module.gsub(":","").underscore + "_path"
    evaluation_path = Rails.application.routes.url_helpers.send(helper_method_name,self)
  end

  def edit_evaluation_path
    evaluationModule = self.evmethod.getEvaluationModule
    helper_method_name = "edit_" + self.evmethod.module.gsub(":","").underscore + "_path"
    evaluation_path = Rails.application.routes.url_helpers.send(helper_method_name,self)
  end

  #Utils

  def self.getValidEvaluationsForItem(evaluations,nItem)
    getValidEvaluationsForItems(evaluations,[nItem])
  end

  def self.getValidEvaluationsForItems(evaluations,nItems)
    # Evaluation.where(:lo_id => Lo.first.id).where('item1!=-1 and item2 !=-1 and item3!=-1 and item17 IS NOT NULL')
    # Usage example: Evaluation.getValidEvaluationsForItems(Evaluation,[1,2,3])
    query = "";
    nItems.each_with_index do |nItem,index|
      if(index!=0)
        query = query + " and "
      end
      query = query + 'item' + (nItem.to_s) + ' != -1'
    end
    evaluations.where(query)
  end

  def self.getItemsArray
    items = []
    getItems.length.times do |i|
      items.push(i+1)
    end
    items
  end


  private

  #Prevent wrong scores to be saved
  def checkScoreBeforeSave
    if !self.score.nil? and Utils.is_numeric?(self.score)
        self.score = [[0,self.score].max,10].min
    end
  end

  def checkAssignment
    # Look for the related assignment of this evaluation
    # It should be a pending assignment of the user with the same Lo and the same evaluation method
    assignment = self.user.assignments.where(:status => "Pending", :lo_id=>self.lo.id, :evmethod_id=>self.evmethod.id).first

    if !assignment.nil?
      #Add the evaluation to the assignment, if its not included
      if self.assignment_id.nil? and !assignment.evaluations.include? self
        assignment.evaluations.push(self)
      end
      unless self.evmethod.allow_multiple_evaluations
        assignment.markAsComplete
      end
      assignment.save!
    end
  end

  def updateScores
    # Look for scores than should be updated or created after create or remove this evaluation

    #1. Get EvMethod of the Evaluation
    #2. Get all the Metrics that used this EvMethod
    #3. For each Metric, create/update the scores of the LO.
    metrics = Metric.allc.select { |m| m.evmethods.include? self.evmethod }
    metrics.each do |m|
      scores = self.lo.scores.where(:metric_id=>m.id)
      if (scores.length > 0)
        #Update Score
        s = scores.first
        loScore = s.metric.class.getScoreForLo(s.lo)
        if loScore.nil?
          #Remove Score
          #TODO
        else
          #Update score
          s.value = loScore
          s.save!
        end
      else
        #Create score
        s = Score.new
        s.metric_id = m.id
        s.lo_id = self.lo.id
        s.save #If the value can't be calculated, the score will not be saved. (Don't use save!)
      end
    end
  end

  def checkCallbacks
    #Look for any web app that want to be notified about this evaluation
    if !self.lo.app.nil? and !self.lo.app.callback.nil?
      #An App wants to be notified that there is new data about this Lo
      LoepNotifier.notifyLoUpdate(self.lo.app,self.lo)
    end
  end
  
end
