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

// onblur validation for all required fields.
// If .book-form is on page, set up form validation logic.
if ($('.book-form').length) {

  // Custom validation for required fields.
  var required = ['site-url', 'book-title', 'author']; // IDs of Required elements.
  $.each(required, function(index, value) {
    // Add onblur handler for alerting when required fields are left empty.
    $('#' + value).blur(function(e){
      if(!$(this).val()) {
        // Print message and add error class.
        $(this).parents('.form-item').addClass('error');
        $('.' + value + '-msg').text('This field is required.');
      } else {
        // Clear message and remove error class.
        $(this).parents('.form-item').removeClass('error');
        $('.' + value + '-msg').empty();
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

