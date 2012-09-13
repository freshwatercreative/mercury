@Mercury.uploader = (file, options) ->
  Mercury.uploader.show(file, options) if Mercury.config.uploading.enabled
  return Mercury.uploader

jQuery.extend Mercury.uploader,

  show: (file, @options = {}) ->
    @file = new Mercury.uploader.File(file)
    if @file.errors
      console.log("Error: #{@file.errors}")
      return
    return unless @supported()

    Mercury.trigger('focus:window')
    @initialize()
    @appear()


  initialize: ->
    return if @initialized
    @build()
    @bindEvents()
    @initialized = true


  supported: ->
    xhr = new XMLHttpRequest

    if window.Uint8Array && window.ArrayBuffer && !XMLHttpRequest.prototype.sendAsBinary
      XMLHttpRequest::sendAsBinary = (datastr) ->
        ui8a = new Uint8Array(datastr.length)
        ui8a[index] = (datastr.charCodeAt(index) & 0xff) for data, index in datastr
        @send(ui8a.buffer)

    return !!(xhr.upload && xhr.sendAsBinary && (Mercury.uploader.fileReaderSupported() || Mercury.uploader.formDataSupported()))

  fileReaderSupported: ->
    !!(window.FileReader)
  
  formDataSupported: ->
    !!(window.FormData)

  determine_format: ->
    if ['application/pdf', "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation"].indexOf(@file.type) > -1
      return "/mercury/documents"
    else
      return "/mercury/images"

  build: ->
    @element = jQuery('<div>', {class: 'mercury-uploader', style: 'display:none'})
    @form = jQuery('<form>', {method: 'put', action:  '/admin/mercury_assets/', id: 'upload_attributes'})
    @form.append('<div class="mercury-uploader-preview"><b><img/></b></div>')
    @form.append('<div class="mercury-uploader-name"><input disabled="true" type="text" name="asset[name]" id="asset[name]" placeholder="Asset Name" /></div>')
    @form.append('<div class="mercury-uploader-format"><select disabled="true" id="asset[named_format]" name="asset[named_format]"><option value="original">Original</option><option value="full">Full Banner (690x250)</option><option value="callout">Banner with Callout (460x250)</option><option value="thumb">Thumbnail (218x100)</option></select>')
    @form.append('<div class="mercury-uploader-details"></div>')
    @form.append('<div class="mercury-uploader-progress"><span></span><div class="mercury-uploader-indicator"><div><b>0%</b></div></div></div>')
    @form.append('<div class="mercury-uploader-update"><button disabled="true" class="button">Update</button></div>')
    @updateStatus('Processing...')
    @overlay = jQuery('<div>', {class: 'mercury-uploader-overlay', style: 'display:none'})
 
    @element.append(@form)

    @element.appendTo(jQuery(@options.appendTo).get(0) ? 'body')
    @overlay.appendTo(jQuery(@options.appendTo).get(0) ? 'body')


  bindEvents: ->
    Mercury.on 'resize', => @position()


  appear: ->
    @fillDisplay()
    @position()

    @overlay.show()
    @overlay.animate {opacity: 1}, 200, 'easeInOutSine', =>
      @element.show()
      @element.animate {opacity: 1}, 200, 'easeInOutSine', =>
        @visible = true
        @loadImage()


  position: ->
    width = @element.outerWidth()
    height = @element.outerHeight()

    @element.css {
      top: (Mercury.displayRect.height - height) / 2
      left: (Mercury.displayRect.width - width) / 2
    }


  fillDisplay: ->
    details = [
      Mercury.I18n('Name: %s', @file.name),
      Mercury.I18n('Size: %s', @file.readableSize)
      #Mercury.I18n('Type: %s', @file.type)
    ]
    @element.find('.mercury-uploader-details').html(details.join('<br/>'))


  loadImage: ->
    if Mercury.uploader.fileReaderSupported()
      if ['image/jpeg', 'image/gif', 'image/png'].indexOf(@file.type) > -1
        @file.readAsDataURL (result) =>
          @element.find('.mercury-uploader-preview b').html(jQuery('<img>', {src: result}))
      @upload()
    else
      @upload()


  upload: ->
    xhr = new XMLHttpRequest
    jQuery.each ['onloadstart', 'onprogress', 'onload', 'onabort', 'onerror'], (index, eventName) =>
      xhr.upload[eventName] = (event) => @uploaderEvents[eventName].call(@, event)
    xhr.onload = (event) =>
      if (event.currentTarget.status >= 400)
        @updateStatus('Error: Unable to upload the file')
        Mercury.notify('Unable to process response: %s', event.currentTarget.status)
        @hide()
      else
        try
          response =
            
            if Mercury.config.uploading.handler
              Mercury.config.uploading.handler(event.target.responseText)
            else
              asset = jQuery.parseJSON(event.target.responseText)
              t = this
              $('#upload_attributes .mercury-uploader-update button').attr("disabled", false) 
              $('#upload_attributes .mercury-uploader-name input').attr("disabled", false) 
              $('#upload_attributes .mercury-uploader-format select').attr("disabled", false) 
              $('#upload_attributes .mercury-uploader-format select').on "change", (event) ->
                filename_match = $("#mercury_iframe").contents().find("#mercury_inserted_image").attr("src").match(/([\w\d_-]*)\.?[^\\\/]*$/)[1]
                $("#mercury_iframe").contents().find("#mercury_inserted_image").attr("src", $("#mercury_iframe").contents().find("#mercury_inserted_image").attr("src").replace(filename_match,$(this).val()))
              $('#upload_attributes .mercury-uploader-update button').on "click", (event) ->
                $("#mercury_iframe").contents().find("#mercury_inserted_image").removeAttr("id")
                $.ajax 
                  type: 'PUT'
                  url: '/admin/mercury_assets/'+asset["id"]
                  dataType: 'json'
                  contentType: 'application/json'
                  data: 
                    JSON.stringify(asset:
                      name: document.getElementById("asset[name]").value
                    )
                error: (jqXHR, textStatus, errorThrown) ->
                  console.log "Error naming image"
                  #$('body').append "AJAX Error #{textStatus}"
                success: (data, textStatus, jqXHR) ->
                  console.log "Image name updated"
                  #$('body').append "Success: #{data}"
                t.hide()
                return(false)

              if ["application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation"].indexOf(@file.type) > -1
                selection = Mercury.region.selection()
                if selection.range.collapsed is false
                  if selection.commonAncestor && selection.commonAncestor(true).find('img').length > 0 
                    content = selection.commonAncestor(true).find('img')[0]
                  else
                    content = selection.fragment.textContent

                container = selection.commonAncestor(true).closest('a') if selection && selection.commonAncestor
                attrs = {href: asset["url"]}
                attrs['target'] = "_blank"
                if container && container.length
                  Mercury.trigger('action', {action: 'replaceLink', value: {tagName: 'a', attrs: attrs, content: content}, node: container.get(0)})
                else
                  Mercury.trigger('action', {action: 'insertLink', value: {tagName: 'a', attrs: attrs, content: content}})
              
              else if ['image/jpeg', 'image/gif', 'image/png'].indexOf(@file.type) > -1
                src=asset["url"]
                throw 'Malformed response from server.' unless src
                Mercury.trigger('action', {action: 'insertImage', value: {src: src, id: "mercury_inserted_image"}})
                #@hide()
        catch error
          @updateStatus('Error: Unable to upload the file')
          Mercury.notify('Unable to process response: %s', error)
          #@hide()

    xhr.open('post', @determine_format(), true)
    xhr.setRequestHeader('Accept', 'application/json, text/javascript, text/html, application/xml, text/xml, */*')
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest')
    xhr.setRequestHeader(Mercury.config.csrfHeader, Mercury.csrfToken)

    # Homespun multipart uploads. Chrome 18, Firefox 11.
    #
    if Mercury.uploader.fileReaderSupported()
      @file.readAsBinaryString (result) =>
        
        multipart = new Mercury.uploader.MultiPartPost(Mercury.config.uploading.inputName, @file, result)

        # update the content size so we can calculate
        @file.updateSize(multipart.delta)

        # set the content type and send
        xhr.setRequestHeader('Content-Type', 'multipart/form-data; boundary=' + multipart.boundary)
        xhr.sendAsBinary(multipart.body)
    
    # FormData based. Safari 5.1.2.
    #
    else
      formData = new FormData()
      formData.append(Mercury.config.uploading.inputName, @file.file, @file.file.name)

      xhr.send(formData)



  updateStatus: (message, loaded) ->
    @element.find('.mercury-uploader-progress span').html(Mercury.I18n(message).toString())
    if loaded
      percent = Math.floor(loaded * 100 / @file.size) + '%'
      @element.find('.mercury-uploader-indicator div').css({width: percent})
      @element.find('.mercury-uploader-indicator b').html(percent).show()


  hide: (delay = 0) ->
    setTimeout =>
      @element.animate {opacity: 0}, 200, 'easeInOutSine', =>
        @overlay.animate {opacity: 0}, 200, 'easeInOutSine', =>
          @overlay.hide()
          @element.hide()
          @reset()
          @visible = false
          Mercury.trigger('focus:frame')
    , delay * 1000


  reset: ->
    @element.find('.mercury-uploader-preview b').html('')
    @element.find('.mercury-uploader-indicator div').css({width: 0})
    @element.find('.mercury-uploader-indicator b').html('0%').hide()
    @updateStatus('Processing...')


  uploaderEvents:
    onloadstart: -> @updateStatus('Uploading...')

    onprogress: (event) -> @updateStatus('Uploading...', event.loaded)

    onabort: ->
      @updateStatus('Aborted')
      @hide(1)

    onload: ->
      @updateStatus('Successfully uploaded...', @file.size)

    onerror: ->
      @updateStatus('Error: Unable to upload the file')
      @hide(3)



class Mercury.uploader.File

  constructor: (@file) ->
    @fullSize = @size = @file.size || @file.fileSize
    @readableSize = @size.toBytes()
    @name = @file.name || @file.fileName
    @type = @file.type || @file.fileType
    @id   = @file.id   || ""

    # add any errors if we need to
    errors = []
    errors.push(Mercury.I18n('Too large')) if @size >= Mercury.config.uploading.maxFileSize
    errors.push(Mercury.I18n('Unsupported format')) unless Mercury.config.uploading.allowedMimeTypes.indexOf(@type) > -1
    @errors = errors.join(' / ') if errors.length


  readAsDataURL: (callback = null) ->
    reader = new FileReader()
    reader.readAsDataURL(@file)
    reader.onload = => callback(reader.result) if callback


  readAsBinaryString: (callback = null) ->
    reader = new FileReader()
    reader.readAsBinaryString(@file)
    reader.onload = => callback(reader.result) if callback


  updateSize: (delta) ->
    @fullSize = @size + delta



class Mercury.uploader.MultiPartPost

  constructor: (@inputName, @file, @contents, @formInputs = {}) ->
    @boundary = 'Boundaryx20072377098235644401115438165x'
    @body = ''
    @buildBody()
    @delta = @body.length - @file.size


  buildBody: ->
    boundary = '--' + @boundary
    for own name, value of @formInputs
      @body += "#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{unescape(encodeURIComponent(value))}\r\n"
    @body += "#{boundary}\r\nContent-Disposition: form-data; name=\"#{@inputName}\"; filename=\"#{@file.name}\"\r\nContent-Type: #{@file.type}\r\nContent-Transfer-Encoding: binary\r\n\r\n#{@contents}\r\n#{boundary}--"


