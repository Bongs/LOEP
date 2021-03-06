class Metric < ActiveRecord::Base
  attr_accessible :name

  validates :name,
  :presence => true,
  :uniqueness => {
    :case_sensitive => false
  }

  validates :type,
  :presence => true,
  :uniqueness => {
    :case_sensitive => true
  }

  validate :evmethods_blank

  def evmethods_blank
    if self.evmethods.blank?
      errors.add(:evmethods, I18n.t("metrics.message.error.one_evmethod_at_least"))
    else
      true
    end
  end

  has_many :scores, :dependent => :destroy
  has_and_belongs_to_many :evmethods
  
  def self.allc
    Metric.where("type in (?)",LOEP::Application.config.metrics.map{|m| m.class.name})
  end

  def self.getInstance
    Metric.find_by_type(self.name)
  end

  def self.getEvmethods
    instance = getInstance
    unless instance.nil?
      instance.evmethods
    else
      []
    end
  end

  def automatic?
    self.evmethods.map{|ev| ev.automatic?}.uniq == [true]
  end

  ################################
  # Method for metrics to inherit
  ################################

  def getScoreForLos(los)
    scores = Hash.new
    los.each do |lo|
      scores[lo.id.to_s] = getScoreForLo(lo)
    end
    scores
  end

  def getScoreForLo(lo)
    getScoreForEvData(lo.getEvaluationData(self.evmethods))
  end

  #This score only makes sense for metrics that only rely on one evmethod.
  def getScoreForEvaluation(evaluation)
    getScoreForEvData(evaluation.getEvaluationData)
  end

  def getScoreForEvData(evData)
    return nil if evData.blank?
    return nil if evData.length < self.evmethods.length #Data about some required evmethod is missed

    evData.each do |key,value|
      itemAverageValues = value[:items]
      return nil if itemAverageValues.compact.blank?
      unless self.class.respond_to?("allowEmptyItems") and self.class.allowEmptyItems
        return nil if itemAverageValues.include? nil
      end
    end

    loScore = self.class.getLoScore(evData)
    loScore = ([[loScore,0].max,10].min).round(2) unless loScore.nil?

    return loScore
  end

  def self.itemWeights
    evmethods = getEvmethods
    itemWeights = []
    unless evmethods.blank?
      itemsLength = evmethods.map{|ev| ev.module.constantize.getItemsWithType("numeric").length}.sum
      itemWeight = 1/itemsLength.to_f
      itemsLength.times do |i|
        itemWeights.push(BigDecimal(itemWeight,6))
      end
    end
    itemWeights
  end

  ################################
  # Method for metrics to implement and override
  ################################

  def self.getLoScore(evData)
    #Override me
  end

end
