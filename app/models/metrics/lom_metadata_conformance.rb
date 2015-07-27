# encoding: utf-8

#Metadata Quality Metric: Completeness

class Metrics::LomMetadataConformance < Metrics::LomMetadataItem

  def self.getScoreForMetadata(metadataFields,options={})
    score = 0
    fieldWeights = Metrics::LomMetadataConformance.fieldWeights
    conformanceItems = Metrics::LomMetadataConformance.conformanceItems
    unless metadataFields.blank?
      metadataFields.each do |key, value|
        unless value.blank? or conformanceItems[key].blank?
          score += getScoreForMetadataField(key,value,options,conformanceItems) * fieldWeights[key]
        end
      end
    end
    score *= 10
    return score
  end

  def self.getScoreForMetadataField(key,value,options={},conformanceItems)
    score = 0
    case conformanceItems[key][:type]
    when "freetext"
      score = getScoreForFreeTextMetadataField(key,value,options,conformanceItems)
    when "categorical"
      score = getScoreForCategoricalMetadataField(key,value,options,conformanceItems)
    end
    [0,[score,1].min].max
  end

  def self.getScoreForFreeTextMetadataField(key,value,options={},conformanceItems)
    score = 0

    allInstances =  MetadataField.where(:name => key)
    unless options[:repository].blank?
      allInstances =  allInstances.where(:repository => options[:repository])
    end
    allInstancesLength = allInstances.count

    processFreeText(value).each do |word,occurrences|
      docWordFrequency = occurrences
      #Calculate repositoryWordFrequency
      repositoryWordFrequency = 0
      instancesWithValue = allInstances.where(:value => word)
      instancesWithValueLength = instancesWithValue.count
      unless allInstancesLength == 0
        repositoryWordFrequency = (instancesWithValueLength.to_f / allInstancesLength)
      end
      unless repositoryWordFrequency==0
        wordScore = docWordFrequency * Math.log(1/repositoryWordFrequency) rescue 0
        score += wordScore
      end
    end

    unless score==0
      score = Math.log(score)

      #Normalize score
      maxiumValue = conformanceItems[key][:max]

      #Store max instance (uncomment to calculate maximumns)
      # allMaxInstances =  MetadataField.where(:name => key + "_max")
      # unless options[:repository].blank?
      #   allMaxInstances =  allMaxInstances.where(:repository => options[:repository])
      # end
      # metadataFieldMaxValueInstance = allMaxInstances.first

      # if metadataFieldMaxValueInstance.nil?
      #   metadataFieldMaxValueInstance = MetadataField.new({:name => key + "_max", :field_type => "max", :value => score, :n => 1, :metadata_id => -1, :repository => options[:repository]})
      #   metadataFieldMaxValueInstance.save!
      # else
      #   if metadataFieldMaxValueInstance.repository == options[:repository]
      #     if score > metadataFieldMaxValueInstance.value.to_f
      #       #Update
      #       metadataFieldMaxValueInstance.value = score
      #       metadataFieldMaxValueInstance.save!
      #     end
      #   end
      # end

      score = [0,[score/(maxiumValue.to_f),1].min].max
    end

    score
  end

  def self.getScoreForCategoricalMetadataField(key,value,options={},conformanceItems)
    score = 0
    allInstances =  MetadataField.where(:name => key)
    unless options[:repository].blank?
      allInstances =  allInstances.where(:repository => options[:repository])
    end
    instancesWithValue = allInstances.where(:value => value)
    n = allInstances.count
    times = instancesWithValue.count
    unless times == 0 or n == 0
      unless n === 1
        score = (1 - (Math.log(times)/Math.log(n))) rescue 0
      else
        score = 1 if times>0 # n=1 and times€{0,1}
      end
    end
    score
  end

  def self.processFreeText(text,options={})
    return {} unless text.is_a? String
    options = {:separator => " "}.merge(options)
    text = text.gsub(/([,.;:?¿¡!\"'_-])/,"").gsub(/([\n])/," ")
    words = Hash.new
    text.split(options[:separator]).each do |word|
      words[word] = 0 if words[word].nil?
      words[word] += 1
    end
    words
  end

  def self.conformanceItems
    cItems = Hash.new
    cItems["1.1.2"] = {type: "freetext", max: 1.5}
    cItems["1.2"] = {type: "freetext", max: 3.25}
    cItems["1.3"] = {type: "categorical"}
    cItems["1.4"] = {type: "freetext", max: 5.5}
    cItems["1.5"] = {type: "freetext", max: 4.25}
    cItems
  end

  def self.fieldWeights
    fieldWeights = {}

    fieldWeights["1.1.1"] = BigDecimal(0,6)
    fieldWeights["1.1.2"] = BigDecimal(0.2,6)
    fieldWeights["1.2"] = BigDecimal(0.25,6)
    fieldWeights["1.3"] = BigDecimal(0.15,6)
    fieldWeights["1.4"] = BigDecimal(0.2,6)
    fieldWeights["1.5"] = BigDecimal(0.2,6)
    fieldWeights["1.6"] = BigDecimal(0,6)
    fieldWeights["1.7"] = BigDecimal(0,6)
    fieldWeights["1.8"] = BigDecimal(0,6)

    fieldWeights["2.1"] = BigDecimal(0,6)
    fieldWeights["2.2"] = BigDecimal(0,6)
    fieldWeights["2.3.1"] = BigDecimal(0,6)
    fieldWeights["2.3.2"] = BigDecimal(0,6)
    fieldWeights["2.3.3"] = BigDecimal(0,6)

    fieldWeights["3.1.1"] = BigDecimal(0,6)
    fieldWeights["3.1.2"] = BigDecimal(0,6)
    fieldWeights["3.2.1"] = BigDecimal(0,6)
    fieldWeights["3.2.2"] = BigDecimal(0,6)
    fieldWeights["3.2.3"] = BigDecimal(0,6)
    fieldWeights["3.3"] = BigDecimal(0,6)
    fieldWeights["3.4"] = BigDecimal(0,6)

    fieldWeights["4.1"] = BigDecimal(0,6)
    fieldWeights["4.2"] = BigDecimal(0,6)
    fieldWeights["4.3"] = BigDecimal(0,6)
    fieldWeights["4.4.1.1"] = BigDecimal(0,6)
    fieldWeights["4.4.1.2"] = BigDecimal(0,6)
    fieldWeights["4.4.1.3"] = BigDecimal(0,6)
    fieldWeights["4.4.1.4"] = BigDecimal(0,6)
    fieldWeights["4.5"] = BigDecimal(0,6)
    fieldWeights["4.6"] = BigDecimal(0,6)
    fieldWeights["4.7"] = BigDecimal(0,6)

    fieldWeights["5.1"] = BigDecimal(0,6)
    fieldWeights["5.2"] = BigDecimal(0,6)
    fieldWeights["5.3"] = BigDecimal(0,6)
    fieldWeights["5.4"] = BigDecimal(0,6)

    fieldWeights["5.5"] = BigDecimal(0,6)
    fieldWeights["5.6"] = BigDecimal(0,6)
    fieldWeights["5.7"] = BigDecimal(0,6)
    fieldWeights["5.8"] = BigDecimal(0,6)
    fieldWeights["5.9"] = BigDecimal(0,6)
    fieldWeights["5.10"] = BigDecimal(0,6)
    fieldWeights["5.11"] = BigDecimal(0,6)

    fieldWeights["6.1"] = BigDecimal(0,6)
    fieldWeights["6.2"] = BigDecimal(0,6)
    fieldWeights["6.3"] = BigDecimal(0,6)

    fieldWeights["7.1"] = BigDecimal(0,6)
    fieldWeights["7.2.1.1"] = BigDecimal(0,6)
    fieldWeights["7.2.1.2"] = BigDecimal(0,6)
    fieldWeights["7.2.2"] = BigDecimal(0,6)

    fieldWeights["8.1"] = BigDecimal(0,6)
    fieldWeights["8.2"] = BigDecimal(0,6)
    fieldWeights["8.3"] = BigDecimal(0,6)

    fieldWeights["9.1"] = BigDecimal(0,6)
    fieldWeights["9.2.1"] = BigDecimal(0,6)
    fieldWeights["9.2.2.1"] = BigDecimal(0,6)
    fieldWeights["9.2.2.2"] = BigDecimal(0,6)
    fieldWeights["9.3"] = BigDecimal(0,6)
    fieldWeights["9.4"] = BigDecimal(0,6)

    fieldWeights
  end

end