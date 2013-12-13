# encoding: utf-8

class Utils < ActiveRecord::Base

  def self.getOptionsForSelectLan(action)
    languages = [["English","en"],["Español","es"],["German","de"],["Nederlands","nl"],["Magyar","hu"],["Français","fr"]]

    if action == "new" or action == "create"
      return languages.push(["Unspecified","Unspecified"])
    else
      return languages
    end
  end

	def self.readable_lan(lan)
    getOptionsForSelectLan(nil).each do |array|
      if array[1] == lan
        return array[0]
      end
    end
    "Unspecified"
  end

  def self.getEvMethods
    Evmethod.all.map { |evmethod| [evmethod.name,evmethod.id] }
  end

  def self.getOptionsForSelectAssignmentStatus
    [["Pending","Pending"],["Completed","Completed"],["Rejected","Rejected"]]
  end


  #Session redirects

  def self.update_return_to(session,request)
    session[:return_to] ||= request.referer
  end

  def self.update_sessions_paths(session, afterDestroy, afterDestroyDependence)
    session.delete(:return_to)
    if !afterDestroy.nil?
      session[:return_to_afterDestroy] = afterDestroy
    else
      session.delete(:return_to_afterDestroy)
    end
    if !afterDestroyDependence.nil?
      session[:return_to_afterDestroyDependence] = afterDestroyDependence
    else
      session.delete(:return_to_afterDestroyDependence)
    end
  end

  def self.return_after_create_or_update(session)
    if session[:return_to]
      session.delete(:return_to)
    else
      Rails.application.routes.url_helpers.home_path
    end
  end

  def self.return_after_destroy_path(session)
    if session[:return_to_afterDestroyDependence]
      session.delete(:return_to_afterDestroy)
      return session.delete(:return_to_afterDestroyDependence)
    elsif session[:return_to_afterDestroy]
      session.delete(:return_to_afterDestroyDependence)
      return session.delete(:return_to_afterDestroy)
    else
      Rails.application.routes.url_helpers.home_path
    end
  end

end