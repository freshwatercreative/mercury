@Mercury.dialogHandlers.tableclasses = ->
  @element.find('[data-tableclass]').on 'click', (event) =>
    className = jQuery(event.target).data('dataclass')
    console.log className
    Mercury.trigger('action', {action: 'style', value: className})
