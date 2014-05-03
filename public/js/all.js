// A temporary Hackaroni-and-cheese version. Later we should replace this with Backbone or something.

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
    $('.other-options').slideDown();
  } else {
    $('.other-options').slideUp();
  }
});

// This tiny function clears out the "Other License" fields on submission if
// the "Other License" radio wasn't checked.
function checkLicense() {
  if(!$('#other').is(':checked')) {
    $('.other-options input').val('');
  }
  return true;
}

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
    $(this).css({"visibility":"hidden",display:'block'}).slideUp();
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

  // cancel animation if there's an error in this fieldset.
  checkRequired(current_fs);
  if (current_fs.find(".error").length) {
    current_fs.find(".error").shake();
    animating = false;
    return false;
  }

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

