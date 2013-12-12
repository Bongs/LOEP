$.rails.allowAction = function(link) {
  if (!link.attr('data-confirm')) {
   return true;
  }
  $.rails.showConfirmDialog(link);
  return false;
};

$.rails.confirmed = function(link) {
  link.removeAttr('data-confirm');
  return link.trigger('click.rails');
};

$.rails.showConfirmDialog = function(link){
  _showLOEPDialog(link.attr('data-confirm'), true, function(result){
    if(result==true){
      //Ok
      return $.rails.confirmed(link);
    } else {
      //Cancel
    }
  })
};

var _showLOEPDialog = function(msg, showCancelButton, callback){
  var html = '<div id="dialog" title="Basic dialog"><p>'+msg+'</p></div>';

  var dialogButtons = {
    "Ok": function() {
      $(this).dialog("close");
      if(typeof callback == "function"){
        callback(true);
      }
    }
  };

  if(showCancelButton===true){
    dialogButtons["Cancel"] = function(){
      $(this).dialog("close");
      if(typeof callback == "function"){
        callback(false);
      }
    }
  }

  $(html).dialog({
    resizable: false,
    // Not specified height = height auto
    // height: 300,
    modal: true,
    dialogClass: 'noTitleStuff',
    open: function() {
      //Fix bug introduced on JQuery UI 1.10.3
      $(this).closest(".ui-dialog")
      .find(".ui-dialog-titlebar-close")
      .removeClass("ui-dialog-titlebar-close")
      .addClass("ui-icon-closethick-wrapper")
      .html("<span class='ui-button-icon-primary ui-icon ui-icon-closethick'></span>");
    },
    buttons: dialogButtons
  });
}

$(document).on('click', '[promptOkAlertDialog="true"]', function(event){
  var link = $(event.target);
  _showLOEPDialog(link.attr('data-confirm'), false);
});




      

