// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
//= require jquery
//= require jquery_ujs
//= require jquery-ui/widgets/datepicker
//= require jquery-ui/i18n/datepicker-pl
//= require jquery-ui/widgets/sortable
//= require jquery-ui/effect
//= require bootstrap-sprockets
//= require_tree .

$(function () {
    $.datepicker.setDefaults($.datepicker.regional[ "pl" ]);
    $.datepicker.setDefaults({ dateFormat: "yy-mm-dd" });
    $.datepicker.setDefaults({ numberOfMonths: 3 });
    $("#inventory_entry_date").datepicker();
});

$(document).ready(function () {
    $('table').delegate('td, th', 'mouseover mouseleave', function (e) {
        if (e.type == 'mouseover') {
            if ($(this).is("td")) {
                $(this).parent().addClass("hover");
            }
            var className = $(this).attr('class');
            if (className) {
                var incomeOrExpense = className.match(/income_(\d+|all)|expense_(\d+|all)/);
                if (incomeOrExpense) {
                    className = incomeOrExpense[0];
                    $('.' + className).addClass("hover");
                    $(this).addClass("hover_dim");
                }
            }
        } else {
            $(this).removeClass("hover_dim");
            $(this).parent().removeClass("hover");
            var className = $(this).attr('class');
            if (className) {
                var incomeOrExpense = className.match(/income_(\d+|all)|expense_(\d+|all)/);
                if (incomeOrExpense) {
                    className = incomeOrExpense[0];
                    $('.' + className).removeClass("hover");
                }
            }
        }
    });
});

// Funkcje do zapisywania preferencji użytkownika w localStorage
function saveUserPreference(key, value) {
  try {
    localStorage.setItem('ziher_' + key, value);
  } catch (e) {
    console.warn('Nie można zapisać preferencji w localStorage:', e);
  }
}

function getUserPreference(key, defaultValue) {
  try {
    var value = localStorage.getItem('ziher_' + key);
    return value !== null ? value : defaultValue;
  } catch (e) {
    console.warn('Nie można odczytać preferencji z localStorage:', e);
    return defaultValue;
  }
}

// Zapisywanie wybranej jednostki
$(document).on('change', 'select[name="unit_select"]', function() {
  saveUserPreference('selected_unit_id', $(this).val());
});

// Zapisywanie wybranego roku
$(document).on('change', 'select[name="year_select"]', function() {
  saveUserPreference('selected_year', $(this).val());
});

// Zapisywanie preferencji paginacji
$(document).on('change', 'select[name="items_per_page"]', function() {
  saveUserPreference('items_per_page', $(this).val());
});

// Inicjalizacja przy załadowaniu strony
$(document).ready(function() {
  // Ustawienie zapamiętanej jednostki jeśli istnieje i nie została już wybrana
  var storedUnitId = getUserPreference('selected_unit_id', null);
  if (storedUnitId) {
    var unitSelect = $('select[name="unit_select"]');
    if (unitSelect.length && !unitSelect.val()) {
      unitSelect.val(storedUnitId);
    }
  }
  
  // Ustawienie zapamiętanego roku jeśli istnieje i nie został już wybrany
  var storedYear = getUserPreference('selected_year', null);
  if (storedYear) {
    var yearSelect = $('select[name="year_select"]');
    if (yearSelect.length && !yearSelect.val()) {
      yearSelect.val(storedYear);
    }
  }
  
  // Ustawienie zapamiętanej liczby elementów na stronę
  var storedItemsPerPage = getUserPreference('items_per_page', null);
  if (storedItemsPerPage) {
    var itemsSelect = $('select[name="items_per_page"]');
    if (itemsSelect.length) {
      itemsSelect.val(storedItemsPerPage);
    }
  }
});
