// A temporary Hackaroni-and-cheese version. Later we should replace this with Backbone or something.
// @todo: Get this stuff in a Document.ready method, so it doesn't have to depend on being loaded after the DOM.

// Behaviors for selecting a theme (See http://stackoverflow.com/questions/4178516).
if($('.theme-options').length !== 0) {

  // Create listener for selecting/highlighting other themes.
  $('.theme-options img').click(function() {
      // Set the form value
      $('#selected_theme').val($(this).attr('data-value'));

      // Unhighlight all the images
      $('.theme-options img').removeClass('highlighted');

      // Highlight the newly selected image
      $(this).addClass('highlighted');
  });
}

// Behaviors for the "Other" license option.
$('input.radio').click(function() {
  if($('#other').is(':checked')) {
    $('.other-options').slideDown('fast');
  } else {
    $('.other-options').slideUp('fast');
  }
});

// Behaviors for Clone vs Existing Project options.
$('input.selection-radio').click(function(e) {
  if($('#existing').is(':checked')) {
    $('.github-options').slideDown('fast');
  } else {
    $('.github-options').slideUp('fast', function(ev) {
      $('.github-warning').remove();
      $('#select_gh_project').prop('selectedIndex', -1);
    });
  }
});

// Warning message when choosing a project with an existing gh-pages branch.
$('#select_gh_project').prop('selectedIndex', -1);
$('#select_gh_project').change(function(e) {
  $('.github-warning').remove();
  checkForGithubPagesBranch();
});

function checkForGithubPagesBranch() {
  var repo_id = $('#select_gh_project option:selected').val();

  // @todo: we should not depend on the error condition for normal use. I read a blog
  // post about this. Just use a condition in the success area. I think my endpoint
  // should actually be "https://api.github.com/repositories/" + repo_id + "/branches"
  // in order to fix this.
  $.ajax({
    url: "https://api.github.com/repositories/" + repo_id + "/branches/gh-pages",
    dataType: "json",
    // Returns "success" if the gh-pages branch exists, and "error" (404) if it doesn't.
    success: function (returndata) {
      var warning = '<div class="flash warning github-warning"><b>WAIT!</b> This project already has a gh-pages branch. If you build a book-site for this project, it will overwrite the contents of your existing Github pages site! <i>Consider yourself warned!</i></div>';
      $('#select_gh_project').after(warning);
      $('.theme-options').after(warning);
    },
    error: function(XMLHttpRequest, textStatus, errorThrown) {
      // If the API is down or we otherwise cannot tell if a github pages branch exists,
      // we provide a message out of an abundance of caution.
      if (errorThrown !== "Not Found") { // It returned a non-404 error.
        var safemessage = '<div class="flash warning github-warning">Heads up! If this project has a github pages branch it will be overwritten.</div>';
        $('#select_gh_project').after(safemessage);
        $('.theme-options').after(safemessage);
      }
    }
  });
}

// Enable the selectize plugin (for github select box). Commented out until I
// can reproduce the validation and warning messages that go with it.
//
//$(function() {
//    $('#select_gh_project').selectize();
//});

// This clears out the "Other License" fields when paginating if
// the "Other License" radio wasn't checked.
$('#section-3-next, #edit-book-submit').click(function(event){
  if(!$('#other').is(':checked')) {
    $('.other-options input').val('');
  }
  return true;
});

// This function checks to see if there are any required, unfilled,
// fields on the page, and creates error messages for them. Good
// for triggering on submit buttons, or on multi-step forms.
function checkRequired(parent) {
  parent.find('[required]').each(function(index) {
    if(!$(this).val()) {
      // Print message and add error class.
      $(this).parents('.form-item').addClass('error');
      $(this).siblings('.msg').text('This field is required.');
    }
  });
}

// Shake plugin
$.fn.shake = function (options) {
  // defaults
  var settings = {
    'shakes': 2,
    'distance': 10,
    'duration': 400
  };
  // merge options
  if (options) {
    $.extend(settings, options);
  }
  // make it so
  var pos;
  return this.each(function () {
    $this = $(this);
    // position if necessary
    pos = $this.css('position');
    if (!pos || pos === 'static') {
        $this.css('position', 'relative');
    }
    // shake it
    for (var x = 1; x <= settings.shakes; x++) {
      $this.animate({ left: settings.distance * -1 }, (settings.duration / settings.shakes) / 4)
        .animate({ left: settings.distance }, (settings.duration / settings.shakes) / 2)
        .animate({ left: 0 }, (settings.duration / settings.shakes) / 4);
      }
  });
};

// Set onblur validation for all required fields.
// If .book-form is on page, set up form validation logic.
if ($('.book-form').length) {
  $('[required]').each(function(index) {
    // Add onblur handler for alerting when required fields are left empty.
    $(this).blur(function(e){
      if(!$(this).val()) {
        // Print message and add error class.
        $(this).parents('.form-item').addClass('error');
        $(this).siblings('.msg').text('This field is required.');
      } else {
        // Clear message and remove error class.
        $(this).parents('.form-item').removeClass('error');
        $(this).siblings('.msg').empty();
      }
    });
  });
}

// Behaviors for flash-message boxes.
$('.flash').append('<a class="icon-cross" href="#"></a>');

$('.flash .icon-cross').click(function(event) {
  event.preventDefault();
  $(this).parent('.flash').fadeOut(1000, function(){
    $(this).css({"visibility":"hidden",display:'block'}).slideUp('fast');
  });
});

// Progress bar and multi-step form animation on the new book page.
var current_fs, next_fs, previous_fs; //fieldsets
var left, opacity, scale; //fieldset properties which we will animate
var animating; //flag to prevent quick multi-click glitches

$(".next").click(function(){
  if(animating) return false;
  animating = true;

  current_fs = $(this).closest("fieldset");
  next_fs = $(this).closest("fieldset").next();

  // cancel animation if there's an error in this fieldset.
  checkRequired(current_fs);
  if (current_fs.find(".error").length) {
    current_fs.find(".error").shake();
    animating = false;
    return false;
  } else if ($('input[name="book[source]"]:checked', '#new-book-form').val() === "existing" && !$('#select_gh_project').val()) {
    $('.github-options').shake();
    animating = false;
    return false;
  }


  //activate next step on progressbar using the index of next_fs
  $(".progressbar li").eq($("fieldset").index(next_fs)).addClass("active");

  //hide the current fieldset with style
  current_fs.animate({opacity: 0}, {
    step: function(now, mx) {
      //as the opacity of current_fs reduces to 0 - stored in "now"
      //1. scale current_fs down to 80%
      scale = 1 - (1 - now) * 0.2;
      current_fs.css({'transform': 'scale('+scale+')'});
    },
    duration: 500,
    complete: function(){
      current_fs.hide();
      // Reset original style values.
      current_fs.css({'transform': 'scale(1)', 'opacity': '1'});
      next_fs.fadeIn();
      animating = false;
    },
    //this comes from the custom easing plugin
    easing: 'swing'
  });
});

$(".previous").click(function(){
  if(animating) return false;
  animating = true;

  current_fs = $(this).closest("fieldset");
  previous_fs = $(this).closest("fieldset").prev();

  //de-activate current step on progressbar
  $(".progressbar li").eq($("fieldset").index(current_fs)).removeClass("active");

  //hide the current fieldset with style
  current_fs.animate({opacity: 0}, {
    step: function(now, mx) {
      //as the opacity of current_fs reduces to 0 - stored in "now"
      //1. scale previous_fs down to 80%
      scale = 1 - (1 - now) * 0.2;
      current_fs.css({'transform': 'scale('+scale+')'});
    },
    duration: 500,
    complete: function(){
      current_fs.hide();
      // Reset original style values.
      current_fs.css({'transform': 'scale(1)', 'opacity': '1'});
      previous_fs.fadeIn();
      animating = false;
    },
    //this comes from the custom easing plugin
    easing: 'swing'
  });
});

// Behaviors on the domain page, including ajax form submission and undo request.

// Ajax Form submission
$('#domain-form').submit(function(event){
  /* stop form from submitting normally */
  event.preventDefault();

  /* disable form elements and set status to processing */
  // Note: I'm not disabling text inputs because then their values
  // aren't accessible by serialize().
  $('#domain-submit').prop('disabled', true);
  $('#domain-form').addClass('processing');

  var endpoint = $(this).attr('action');

  $.ajax({
      type: "PUT",
      url: endpoint,
      data: $(this).serialize(),
      success: function(){
        // Hide the original form and show the post-form message.
        $('#domain-form .form-item').toggle();
        $('.received').toggle();

        // Re-enable the button and end processing
        $('#domain-submit').prop('disabled', false);
        $('#domain-form').removeClass('processing');

        // We always populate the field with the original domain value because
        // if they want to 'undo' their change, the original value can be sent.
        // It also makes sense after the 'undo' because we want the field to be
        // prepopulated with the value in the database (like blog posts in a CMS).
        $('#domain').val($('#domain-form').attr('data-url'));

      },
      error: function(){
        // If a pre-existing error message was on the page, remove it.
        $('#ajax-error').remove();

        // Make and post a new error message.
        var message = '<div id="ajax-error" class="flash warning">Oops, something went wrong. Try again later.<a class="icon-cross" href="#"></a></div>';
        $('.custom-domain > .inside').prepend(message);
      }
    });
});

