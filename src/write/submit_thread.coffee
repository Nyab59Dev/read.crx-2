do ->
  return if navigator.platform.includes("Win")
  font = localStorage.getItem("textar_font")
  return unless font?
  fontface = new FontFace("Textar", "url(#{font})")
  document.fonts.add(fontface)
  return

app.boot("/write/submit_thread.html", ->
  param = app.URL.parseQuery(location.search)
  arg =
    url: app.URL.fix(param.get("url"))
    title: param.get("title") ? param.get("url")
    name: param.get("name") ? app.config.get("default_name")
    mail: param.get("mail") ? app.config.get("default_mail")
    message: param.get("message") ? ""

  chrome.tabs.getCurrent( ({id}) ->
    chrome.webRequest.onBeforeSendHeaders.addListener( ({method, url, requestHeaders}) ->
      origin = chrome.extension.getURL("")[...-1]
      isSameOrigin = requestHeaders.some( ({name, value}) ->
        return name is "Origin" and (value is origin or value is "null")
      )
      if method is "POST" and isSameOrigin
        refUrl = arg.url
        if app.URL.tsld(refUrl) is "2ch.sc"
          refUrl = app.URL.setScheme(refUrl, "http")
        requestHeaders.push(name: "Referer", value: refUrl)

        # UA変更処理
        ua = app.config.get("useragent").trim()
        if ua.length > 0
          for {name}, i in requestHeaders when name is "User-Agent"
            requestHeaders[i].value = ua
            break

        return {requestHeaders}
      return
    {
      tabId: id
      types: ["sub_frame"]
      urls: [
        "*://*.5ch.net/test/bbs.cgi*"
        "*://*.bbspink.com/test/bbs.cgi*"
        "*://*.2ch.sc/test/bbs.cgi*"
        "*://*.open2ch.net/test/bbs.cgi*"
        "*://jbbs.shitaraba.net/bbs/write.cgi/*"
      ]
    }
    ["requestHeaders", "blocking"])
    return
  )

  $view = $$.C("view_write")[0]

  $view.C("preview_button")[0].on("click", (e) ->
    e.preventDefault()

    text = $view.T("textarea")[0].value
    #行頭のスペースは削除される。複数のスペースは一つに纏められる。
    text = text.replace(/^\u0020*/g, "").replace(/\u0020+/g, " ")

    $div = $__("div")
    $div.addClass("preview")
    $pre = $__("pre")
    $pre.textContent = text
    $div.addLast($pre)
    $button = $__("button")
    $button.addClass("close_preview")
    $button.textContent = "戻る"
    $button.on("click", ->
      @parentElement.remove()
      return
    )
    $div.addLast($button)
    document.body.addLast($div)
    return
  )

  $view.C("message")[0].on("keyup", ->
    line = @value.split(/\n/).length
    $view.C("notice")[0].textContent = "#{@value.length}文字 #{line}行"
    return
  )

  $sage = $view.C("sage")[0]
  $mail = $view.C("mail")[0]

  if app.config.isOn("sage_flag")
    $sage.checked = true
    $mail.disabled = true
  $view.C("sage")[0].on("change", ->
    if @checked
      app.config.set("sage_flag", "on")
      $mail.disabled = true
    else
      app.config.set("sage_flag", "off")
      $mail.disabled = false
    return
  )

  $notice = $view.C("notice")[0]
  onError = (message) ->
    for dom from $view.$$("form input, form textarea")
      dom.disabled = false unless dom.hasClass("mail") and app.config.isOn("sage_flag")

    if message
      $notice.textContent = "書き込み失敗 - #{message}"
    else
      $notice.textContent = ""
      UI.Animate.fadeIn($view.C("iframe_container")[0])
    return

  writeTimer =
    wake: ->
      @kill() if @timer?
      @timer = setTimeout( ->
        onError("一定時間経過しても応答が無いため、処理を中断しました")
        return
      , 1000 * 30)
      return
    kill: ->
      clearTimeout(@timer)
      @timer = null
      return

  window.on("message", ({data, source}) ->
    {type, key, message} = JSON.parse(data)
    switch type
      when "ping"
        source.postMessage("write_iframe_pong:thread", "*")
        writeTimer.wake()
      when "success"
        $notice.textContent = "書き込み成功"
        setTimeout( ->
          mes = $view.C("message")[0].value
          name = $view.C("name")[0].value
          mail = $view.C("mail")[0].value
          title = $view.C("title")[0].value
          if app.URL.tsld(arg.url) in ["5ch.net", "2ch.sc", "bbspink.com", "open2ch.net"]
            keys = key.match(/.*\/test\/read\.cgi\/(\w+?)\/(\d+)\/l\d+/)
            unless keys?
              $notice.textContent = "書き込み失敗 - 不明な転送場所"
            else
              server = arg.url.match(/^(https?:\/\/\w+\.(?:5ch\.net|2ch\.sc|bbspink\.com|open2ch\.net)).*/)[1]
              url = "#{server}/test/read.cgi/#{keys[1]}/#{keys[2]}"
              chrome.runtime.sendMessage({type: "written", kind: "own", url: arg.url, thread_url: url, mes, name, mail, title})
          else if app.URL.tsld(arg.url) is "shitaraba.net"
            chrome.runtime.sendMessage({type: "written", kind: "board", url: arg.url, mes, name, mail, title})
          chrome.tabs.getCurrent( ({id}) ->
            chrome.tabs.remove(id)
            return
          )
          return
        , 3000)
        writeTimer.kill()
      when "confirm"
        UI.Animate.fadeIn($view.C("iframe_container")[0])
        writeTimer.kill()
      when "error"
        onError(message)
        writeTimer.kill()
    return
  )

  $view.C("hide_iframe")[0].on("click", ->
    writeTimer.kill()
    $iframeContainer = $view.C("iframe_container")[0]
    UI.Animate.fadeOut($iframeContainer).on("finish", ->
      $iframeContainer.T("iframe")[0].remove()
      return
    )
    for dom from $view.$$("input, textarea")
      dom.disabled = false unless dom.hasClass("mail") and app.config.isOn("sage_flag")
    $notice.textContent = ""
    return
  )

  document.title = arg.title + "板"
  $h1 = $view.T("h1")[0]
  $h1.textContent = arg.title + "板"
  $h1.addClass("https") if app.URL.getScheme(arg.url) is "https"
  $view.C("name")[0].value = arg.name
  $view.C("mail")[0].value = arg.mail
  $view.C("message")[0].value = arg.message

  $view.T("form")[0].on("submit", (e) ->
    e.preventDefault()

    for dom from $view.$$("input, textarea")
      dom.disabled = true unless dom.hasClass("mail") and app.config.isOn("sage_flag")

    {bbsType} = app.URL.guessType(arg.url)
    scheme = app.URL.getScheme(arg.url)

    iframeArg =
      rcrxName: $view.C("name")[0].value
      rcrxMail: if $view.C("sage")[0].checked then "sage" else $view.C("mail")[0].value
      rcrxTitle: $view.C("title")[0].value
      rcrxMessage: $view.C("message")[0].value

    $iframe = $__("iframe")
    $iframe.src = "/view/empty.html"
    $iframe.on("load", ->
      tmp = arg.url.split("/")
      #2ch
      if bbsType is "2ch"
        #open2ch
        if app.URL.tsld(arg.url) is "open2ch.net"
          formData =
            action: "#{scheme}://#{tmp[2]}/test/bbs.cgi"
            charset: "UTF-8"
            input:
              submit: "新規スレッド作成"
              bbs: tmp[3]
              subject: iframeArg.rcrxTitle
              FROM: iframeArg.rcrxName
              mail: iframeArg.rcrxMail
            textarea:
              MESSAGE: iframeArg.rcrxMessage
        else
          formData =
            action: "#{scheme}://#{tmp[2]}/test/bbs.cgi"
            charset: "Shift_JIS"
            input:
              submit: "新規スレッド作成"
              time: Math.floor(Date.now() / 1000) - 60
              bbs: tmp[3]
              subject: iframeArg.rcrxTitle
              FROM: iframeArg.rcrxName
              mail: iframeArg.rcrxMail
            textarea:
              MESSAGE: iframeArg.rcrxMessage
      #したらば
      else if bbsType is "jbbs"
        formData =
          action: "#{scheme}://jbbs.shitaraba.net/bbs/write.cgi/#{tmp[3]}/#{tmp[4]}/new/"
          charset: "EUC-JP"
          input:
            submit: "新規スレッド作成"
            TIME: Math.floor(Date.now() / 1000) - 60
            DIR: tmp[3]
            BBS: tmp[4]
            SUBJECT: iframeArg.rcrxTitle
            NAME: iframeArg.rcrxName
            MAIL: iframeArg.rcrxMail
          textarea:
            MESSAGE: iframeArg.rcrxMessage
      #フォーム生成
      form = @contentDocument.createElement("form")
      form.setAttribute("accept-charset", formData.charset)
      form.action = formData.action
      form.method = "POST"
      for key, val of formData.input
        input = @contentDocument.createElement("input")
        input.name = key
        input.setAttribute("value", val)
        form.appendChild(input)
      for key, val of formData.textarea
        textarea = @contentDocument.createElement("textarea")
        textarea.name = key
        textarea.textContent = val
        form.appendChild(textarea)
      @contentDocument.body.appendChild(form)
      Object.getPrototypeOf(form).submit.call(form)
      return
    , once: true)
    $$.C("iframe_container")[0].addLast($iframe)

    writeTimer.wake()

    $notice.textContent = "書き込み中"
    return
  )

  window.on("beforeunload", ->
    chrome.runtime.sendMessage(type: "writesize", x: screenX, y: screenY)
    return
  )
  return
)
