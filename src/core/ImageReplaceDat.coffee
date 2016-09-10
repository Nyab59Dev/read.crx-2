###*
@namespace app
@class NG
@static
###
class app.ImageReplaceDat
  _dat = []
  _reg = /^([^\t]+)(?:\t([^\t]+)(?:\t([^\t]+)(?:\t([^\t]+)(?:\t([^\t]+)(?:\t([^\t]+))?)?)?)?)?/
  _configName = "image_replace_dat_obj"
  _configStringName = "image_replace_dat"

  #jsonには正規表現のオブジェクトが含めれないので
  #それを展開
  _setupReg = () ->
    for d in _dat
      d.baseUrlReg = new RegExp d.baseUrl
      if d.scrapingPattern isnt ""
        d.scrapingPatternReg = new RegExp d.scrapingPattern
    return

  _config =
    get: ->
      return JSON.parse(app.config.get(_configName))
    set: (str) ->
      app.config.set(_configName, JSON.stringify(str))
      return
    getString: ->
      return app.config.get(_configStringName)
    setString: (str) ->
      app.config.set(_configStringName, str)
      return

  _getCookie = (string, dat) ->
    def = $.Deferred()
    req = new app.HTTP.Request("GET", string.replace(dat.baseUrl, dat.referrerUrl))
    #req.headers["Referer"] = string.replace(dat.baseUrl, dat.param.referrerUrl)
    if dat.userAgent isnt "" then req.headers["User-Agent"] = dat.userAgent
    req.send((res) ->
      if res.status is 200
        cookieStr = dat.header["Set-Cookie"]
        def.resolve(cookieStr)
      def.reject()
      return
    )
    return def.promise()

  _getExtract = (string, dat) ->
    def = $.Deferred()
    req = new app.HTTP.Request("GET", string.replace(dat.baseUrlReg, dat.referrerUrl))
    req.headers["Content-Type"] = "text/html"
    #req.headers["Referer"] = string.replace(dat.baseUrlReg, dat.param.referrerUrl)
    if dat.userAgent isnt "" then req.headers["User-Agent"] = dat.userAgent
    req.send((res) ->
      if res.status is 200
        def.resolve(res.body.match(dat.param.patternReg))
      def.reject()
      return
    )
    return def.promise()

  ###*
  @method get
  @return {Object}
  ###
  @get: ->
    if _dat.length is 0
      _dat = _config.get()
      _setupReg()
    return _dat

  ###*
  @method parse
  @param {String} string
  @return {Object}
  ###
  @parse: (string) ->
    dat = []
    if string isnt ""
      datStrSplit = string.split("\n")
      for d in datStrSplit
        if d.startsWith("//") or d.startsWith(";") or d.startsWith("'") or d.startsWith("#")
          continue
        r = _reg.exec(d)
        if r? and r[1]?
          obj =
            baseUrl: r[1]
            replaceUrl: if r[2]? then r[2] else ""
            referrerUrl: if r[3]? then r[3] else ""
            userAgent: if r[6]? then r[6] else ""

          if r[4]?
            obj.param = {}
            rurl = r[4].split("=")[1]
            if r[4].includes("$EXTRACT")
              obj.param.type = "extract"
              obj.param.pattern = r[5]
              obj.param.referrerUrl = if rurl? then rurl else ""
            else if r[4].includes("$COOKIE")
              obj.param.type = "cookie"
              obj.param.referrerUrl = if rurl? then rurl else ""
          dat.push(obj)
    return dat

  ###*
  @method set
  @param {String} string
  ###
  @set: (string) ->
    _dat = @parse(string)
    _config.set(_dat)
    _setupReg()
    console.log _dat
    return

  ###
  @method replace
  @param {HTMLElement} a
  @param {String} string
  @return {Object}
  ###
  @do: (a, string) ->
    def = $.Deferred()
    dat = @get()
    doing = false
    for d in dat when d.baseUrlReg.test(string)
      continue if d.baseUrl is "invalid://invalid"
      continue if d.replaceUrl is ""

      doing = true
      res = {}
      res.referrer = string.replace(dat.baseUrl, dat.referrerUrl)
      if d.param? and d.param.type is "extract"
        _getExtract(string, d).done((exMatch) ->
          res.text = string
            .replace(d.baseUrlReg, d.replaceUrl)
            .replace(/\$EXTRACT(\d+)?/g, (str, num) ->
              if num?
                return exMatch[num]
              else
                return exMatch[1]
            )
          def.resolve(a, res)
          return
        ).fail(->
          def.reject(a, "Fail getExtract")
          return
        )
      else
        res.text = string.replace(d.baseUrlReg, d.replaceUrl)
        if d.param? and d.param.type is "cookie"
          _getCookie(string, d).done((cookieStr) ->
            res.cookie = cookieStr
            def.resolve(a, res)
            return
          ).fail(->
            def.reject(a, "Fail getCookie")
            return
          )
        else
          def.resolve(a, res)
    def.reject(a, "Fail noBaseUrlReg") unless doing
    return def.promise()
