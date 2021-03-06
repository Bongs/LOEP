# encoding: utf-8

namespace :metadata do

	#How to use: bundle exec rake metadata:updateMetadataFieldRecords
	#In production: bundle exec rake metadata:updateMetadataFieldRecords RAILS_ENV=production
	task :updateMetadataFieldRecords => :environment do |t, args|
		puts "Updating MetadataFields and GroupedMetadataFields"

		#Remove previous metadata records
		# MetadataField.destroy_all
		# GroupedMetadataField.destroy_all
		#Delete all is much faster than destroy all, but should be used only when there is no relations with other models.
		MetadataField.delete_all
		GroupedMetadataField.delete_all
		

		#Get conformance items
		conformanceItems = Metrics::LomMetadataConformance.conformanceItems

		Metadata.all.each do |metadataRecord|
			metadata_fields = metadataRecord.getMetadata({:fields => true})
			conformanceItems.each do |key,value|
				unless metadata_fields[key].blank?
					case conformanceItems[key][:type]
					when "freetext"
						generateFreeTextMetadataField(key,metadata_fields[key],metadataRecord)
					when "categorical"
						generateCategoricalMetadataField(key,metadata_fields[key],metadataRecord)
					end
				end
			end
		end

		#Create grouped metadata fields
		repositories = (MetadataField.all.map{|mf| mf.repository} + [nil]).uniq
		conformanceItems.each do |key,value|
			fieldType = conformanceItems[key][:type]
			metadataFields = MetadataField.where(:name => key, :field_type => fieldType)
			repositories.each do |repository|
				unless repository.nil?
					metadataFieldsOfRepository = metadataFields.where(:repository => repository)
				else
					metadataFieldsOfRepository = metadataFields
				end
				#Store the total number of resources that have defined a value for this key/repository pair.
				nTotal = metadataFieldsOfRepository.map{|m| m.metadata_id}.uniq.length
				if nTotal > 0
					g = GroupedMetadataField.new({:name => key, :field_type => fieldType, :repository => repository, :value => nil, :n => nTotal})
					g.save!
				end
				#Values. Store the total number of each value for this key/repository pair.
				values = metadataFieldsOfRepository.map{|m| m.value}.uniq
				values.each do |value|
					n = metadataFieldsOfRepository.where(:value => value).map{|m| m.metadata_id}.uniq.length
					if n > 0
						g = GroupedMetadataField.new({:name => key, :field_type => fieldType, :repository => repository, :value => value, :n => n})
						g.save!
					end
				end
			end
		end
	end

	#How to use: bundle exec rake metadata:updateGraphs
	#In production: bundle exec rake metadata:updateGraphs RAILS_ENV=production
	task :updateGraphs => :environment do |t, args|
		puts "Updating graphs"
		MetadataGraphLink.all.map{|mgl| mgl.destroy}
		
		metadataMapping = Metadata.all.map{|m| [m.id,m.repository,m.getMetadata(:schema => "LOMv1.0", :format => "json", :fields => true)]}.reject{|map| map[2].blank? or map[2]["1.5"].blank? }.map{|map| [map[0],map[1],map[2]["1.5"].split(", ")]}
		metadataMapping.each do |metadataMappingItem|
			# metadata_id = metadataMappingItem[0]
			# repository = metadataMappingItem[1]
			# keywords = metadataMappingItem[2]

			#Normalize keywords and remove duplicates
			metadataMappingItem[2] = UtilsTfidf.normalizeArray(metadataMappingItem[2])
			metadataMappingItem[2].each do |keyword|
				mgl = MetadataGraphLink.new({:metadata_id => metadataMappingItem[0], :keyword => keyword})
				mgl.save!
			end
		end

		#Calculate maximum number of links (most connected object)
		maxLinks = {}
		repositories = (metadataMapping.map{|map| map[1]} + [nil]).uniq
		repositories.each do |repository|
			maxLinks[repository] = []
		end
		metadataMapping.each do |metadataMapping|
			options = {}
			options.merge({:repository => metadataMapping[1]}) unless metadataMapping[1].blank?
			links = MetadataGraphLink.getLinksForKeywords(metadataMapping[2],options)
			maxLinks[metadataMapping[1]].push(links)
		end
		MetadataField.where(:name => "metadataGraphLink_max", :field_type => "max").map{ |mf| mf.destroy}
		maxLinks.each do |repository,maxLinksForRepository|
			maxLinksForRepository = [1] if maxLinksForRepository.blank?

			# maxLink = maxLinksForRepository.max
			require 'descriptive_statistics'
			maxLink = maxLinksForRepository.percentile(70)

			maxLink = MetadataField.updateMax("metadataGraphLink",maxLink,{:repository => repository})
		end
	end

	def generateFreeTextMetadataField(metadataKey,metadataValue,metadataRecord)
		return if  metadataValue.blank?
		UtilsTfidf.processFreeText(metadataValue).each do |word,occurrences|
			mf = MetadataField.new({:name => metadataKey, :field_type => "freetext", :value => word, :n => occurrences, :metadata_id => metadataRecord.id})
			mf.save!
		end
	end

	def generateCategoricalMetadataField(metadataKey,metadataValue,metadataRecord)
		return if  metadataValue.blank?
		mf = MetadataField.new({:name => metadataKey, :field_type => "categorical", :value => UtilsTfidf.normalizeText(metadataValue), :n => 1, :metadata_id => metadataRecord.id})
		mf.save!
	end

end