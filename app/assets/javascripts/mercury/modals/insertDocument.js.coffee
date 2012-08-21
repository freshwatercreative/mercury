@Mercury.modalHandlers.insertDocument = {

  initialize: ->
    @editing = false
    @content = null
    @element.find('.control-label input').on('click', @onLabelChecked)
    @element.find('.controls .optional, .controls .required').on('focus', (event) => @onInputFocused($(event.target)))

    @focus('#media_document_url')
    @initializeForm()

    #show/hide the link target options on target change
    @element.find('#link_target').on('change', => @onChangeTarget())

    # build the image or embed/iframe on form submission
    @element.find('form').on 'submit', (event) =>
      event.preventDefault()
      @validateForm()
      unless @valid
        @resize()
        return
      @submitForm()
      @hide()


  initializeForm: ->
    # get the selection and initialize its information into the form
    return unless Mercury.region && Mercury.region.selection
    selection = Mercury.region.selection()
    @element.find('#link_text').val(selection.textContent()) if selection.textContent
    # if we're editing an image prefill the information
    
    a = selection.commonAncestor(true).closest('a') if selection && selection.commonAncestor
    img = /<img/.test(selection.htmlContent()) if selection.htmlContent
    return false unless img || a && a.length

    # don't allow changing the content on edit
    @element.find('#link_text_container').hide()

    @content = selection.htmlContent() if img

    return false unless a && a.length
    @editing = a

    # if it has a target, select it, and try to pull options out
    if a.attr('target')
      @element.find('#link_target').val(a.attr('target'))

    # if it's a popup window
    if a.attr('href') && a.attr('href').indexOf('javascript:void') == 0
      href = a.attr('href')
      @element.find('#link_external_url').val(href.match(/window.open\('([^']+)',/)[1])
      @element.find('#link_target').val('popup')
      @element.find('#link_popup_width').val(href.match(/width=(\d+),/)[1])
      @element.find('#link_popup_height').val(href.match(/height=(\d+),/)[1])
      @element.find('#popup_options').show()

  focus: (selector) ->
    setTimeout((=> @element.find(selector).focus()), 300)


  onLabelChecked: ->
    forInput = jQuery(@).closest('.control-label').attr('for')
    jQuery(@).closest('.control-group').find("##{forInput}").focus()


  onInputFocused: (input) ->
    input.closest('.control-group').find('input[type=radio]').prop('checked', true)

    return if input.closest('.document-options').length
    @element.find(".document-options").hide()
    @element.find("##{input.attr('id').replace('document_', '')}_options").show()
    @resize(true)


  addInputError: (input, message) ->
    input.after('<span class="help-inline error-message">' + Mercury.I18n(message) + '</span>').closest('.control-group').addClass('error')
    @valid = false


  clearInputErrors: ->
    @element.find('.control-group.error').removeClass('error').find('.error-message').remove()
    @valid = true


  validateForm: ->
    @clearInputErrors()

  submitForm: ->
    link_text = @element.find('input#link_text').val()
    asset_url = @element.find('#media_document_url').val()
    content = @element.find('#link_text').val()
    target = @element.find('#link_target').val()
    attrs = {href: asset_url}
    attrs['target'] = target if target

    value = {tagName: 'a', attrs: attrs, content: @content || content} 

    if @editing
      Mercury.trigger('action', {action: 'replaceLink', value: value, node: @editing.get(0)})
    else
      Mercury.trigger('action', {action: 'insertLink', value: value})
    

      

     

}
