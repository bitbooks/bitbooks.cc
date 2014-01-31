// A temporary Hackaroni-and-cheese version. Later we should replace this with Backbone or something.

// Behaviors for selecting a theme (See http://stackoverflow.com/questions/4178516).
if($('.theme-options').length !== 0) {
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

// onblur validation for all required fields.
// If .book-form is on page, set up form validation logic.
if ($('.book-form').length) {

  // Custom validation for required fields.
  var required = ['site-url', 'book-title', 'author'];
  $.each(required, function(index, value) {
    // Add onblur handler for alerting when required fields are left empty.
    $('#' + value).blur(function(e){
      if(!$(this).val()) {
        // Print message and add error class.
        $(this).parents('.form-item').addClass('error');
        $('.' + value + '-msg').append('This field is required.');
      } else {
        // Clear message and remove error class.
        $(this).parents('.form-item').removeClass('error');
        $('.' + value + '-msg').empty();
      }
    });
  });
}

// Behaviors for message boxes.
$('.flash').append('<a class="icon-cross" href="#"></a>');

$('.flash .icon-cross').click(function(event) {
  event.preventDefault();
  $(this).parent('.flash').fadeOut(1000, function(){
    $(this).css({"visibility":"hidden",display:'block'}).slideUp();
  });
});