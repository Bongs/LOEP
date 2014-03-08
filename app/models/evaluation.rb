class Evaluation < ActiveRecord::Base
  attr_accessible :user_id, :assignment_id, :lo_id, :evmethod_id, :completed_at, :comments,
  :item1, :item2, :item3, :item4, :item5, :item6, :item7, :item8, :item9, :item10, :item11, :item12, :item13, :item14, :item15, :item16, :item17, :item18, :item19, :item20, :item21, :item22, :item23, :item24, :item25,
  :titem1, :titem2, :titem3, :titem4, :titem5, :titem6, :titem7, :titem8, :titem9, :titem10,
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

  after_save :update_assignments
  after_save :update_scores


  def readable_completed_at
    Utils.getReadableDate(self.completed_at)
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
    evaluations.where('item' + (nItem.to_s) + ' != -1')
  end


  private

  def update_assignments
    # Look assignments that can be considered completed after this evaluation
    # Pending assignments of the user, with the same Lo and the same evaluation method
    candidate_assignments = self.user.assignments.where(:status => "Pending", :lo_id=>self.lo.id, :evmethod_id=>self.evmethod.id)
    candidate_assignments.each do |as|
      # #Add the evaluation to the assignment, if its not included
      if as.evaluation.nil?
        as.evaluation = self
      end
      as.status = "Completed"
      as.completed_at = Time.now
      as.save!
    end
  end

  def update_scores
    # Look for scores than should be updated or created after create or remove this evaluation

    #1. Get EvMethod of the Evaluation
    #2. Get all the Metrics that used this EvMethod
    #3. For each Metric, create/update the scores of the LO.
    metrics = Metric.all.select { |m| m.evmethods.include? self.evmethod }
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
  
end
