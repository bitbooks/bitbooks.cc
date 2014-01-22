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

// Client-side form validation.
//
// Jquery validation plugin (Currently not working)
//
// if (document.getElementById('new-book-form')) {
//   alert("form is here");
//   $('new-book-form').validate({
//     onfocusout: function (element) {
//       this.element(element);
//     },
//     rules: {
//       'book[github_url]': {
//         required: true
//       },
//       'book[subdomain]': {
//         required: true
//       },
//       'book[title]': {
//         required: true
//       },
//       'book[author]': {
//         required: true
//       }
//     },
//     messages: {
//       'book[github_url]': 'You must pick a github project.',
//       'book[subdomain]': 'This field is required',
//       'book[title]': 'This field is required',
//       'book[author]': 'This field is required'
//     },
//     //highlight: function(element) {
//     //  $(element).closest('.control-group').removeClass('success').addClass('error');
//     //}
//    });
// }
// if (document.getElementById('edit-book-form')) {
//    $('edit-book-form').validate();
// }


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

  // Custom validation for image field file type. See http://stackoverflow.com/a/4329103/1154642
  var file = document.getElementById('cover-image');
  file.onchange = function(e){
    var ext = this.value.match(/\.([^\.]+)$/)[1];
    switch(ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        // Filetype is allowed. Empty any previously set messages.
        $('.image-invalid').empty();
        break;
      default:
        $('.image-invalid').empty().append('Oops. That file type is not allowed. Please make another choice.');
        // This line clears out the loaded file. I think that's a bit confusing, so I'm leaving it off for now.
        // this.value='';
    }
  };
}

// Behaviors for message boxes.
$('.flash').append('<a class="icon-cross" href="#"></a>');

$('.flash .icon-cross').click(function(event) {
  event.preventDefault();
  $(this).parent('.flash').fadeOut(1000, function(){
    $(this).css({"visibility":"hidden",display:'block'}).slideUp();
  });
});