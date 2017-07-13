app.boot "/view/board.html", ->
  try
    url = app.URL.parseQuery(location.search).get("q")
  catch
    alert("不正な引数です")
    return
  url = app.URL.fix(url)
  opened_at = Date.now()

  $view = document.documentElement
  $view.setAttr("data-url", url)

  $table = $__("table")
  threadList = new UI.ThreadList($table, {
    th: ["bookmark", "title", "res", "unread", "heat", "createdDate"]
    searchbox: $view.C("searchbox")[0]
  })
  app.DOMData.set($view, "threadList", threadList)
  app.DOMData.set($view, "selectableItemList", threadList)
  tableSorter = new UI.TableSorter($table)
  app.DOMData.set($table, "tableSorter", tableSorter)
  for dom in $table.$$("th.res, th.unread, th.heat")
    dom.dataset.tableSortType = "num"
  $$.C("content")[0].addLast($table)

  write = (param) ->
    param or= {}
    param.title = document.title
    param.url = url
    open(
      "/write/submit_thread.html?#{app.URL.buildQuery(param)}"
      undefined
      'width=600,height=400'
    )

  if app.URL.tsld(url) in ["2ch.net", "shitaraba.net", "bbspink.com", "2ch.sc", "open2ch.net"]
    $view.C("button_write")[0].on "click", ->
      write()
      return
  else
    $view.C("button_write")[0].remove()

  # 現状ではしたらばはhttpsに対応していないので切り替えボタンを隠す
  if app.URL.tsld(url) is "shitaraba.net"
    $view.C("button_scheme")[0].remove()

  do ->
    tmp = app.config.get("last_board_sort_config")
    if tmp?
      tableSorter.updateSnake(JSON.parse(tmp))
    return
  $table.on "table_sort_updated", ({detail}) ->
    app.config.set("last_board_sort_config", JSON.stringify(detail))
    return
  #.sort_item_selectorが非表示の時、各種項目のソート切り替えを
  #降順ソート→昇順ソート→標準ソートとする
  $table.on "click", (e) ->
    return unless e.target.tagName is "TH" and e.target.hasClass("table_sort_asc")
    return unless $view.C("sort_item_selector")[0].offsetWidth is 0
    $table.on("table_sort_before_update", func = (e) ->
      $table.off("table_sort_before_update", func)
      e.preventDefault()
      tableSorter.update(
        sortAttribute: "data-thread-number"
        sortOrder: "asc"
        sortType: "num"
      )
      return
    )
    return

  new app.view.TabContentView($view)

  app.BoardTitleSolver.ask(url).then (title) ->
    if title
      document.title = title
    if app.config.get("no_history") is "off"
      app.History.add(url, title or url, opened_at)
    return

  load = (ex) ->
    $view.addClass("loading")
    app.message.send("request_update_read_state", {board_url: url})

    setTimeout( ->
      get_read_state_promise = app.ReadState.getByBoard(url)

      board_get_promise = new Promise( (resolve, reject) ->
        app.board.get url, (res) ->
          $message_bar = $view.C("message_bar")[0]
          if res.status is "error"
            $message_bar.addClass("error")
            $message_bar.innerHTML = res.message
          else
            $message_bar.removeClass("error")
            $message_bar.removeChildren()

          if res.data?
            resolve(res.data)
          else
            reject()
          return
        return
      )

      Promise.all([get_read_state_promise, board_get_promise])
        .then ([array_of_read_state, board]) ->
          read_state_index = {}
          for read_state, key in array_of_read_state
            read_state_index[read_state.url] = key

          threadList.empty()
          item = []
          for thread, thread_number in board
            readState = array_of_read_state[read_state_index[thread.url]]
            if (bookmark = app.bookmark.get(thread.url))?.read_state?
              readState = bookmark.read_state
            item.push(
              title: thread.title
              url: thread.url
              res_count: thread.res_count
              created_at: thread.created_at
              read_state: readState
              thread_number: thread_number
              ng: thread.ng
              need_less: thread.need_less
              is_net: thread.is_net
            )
          threadList.addItem(item)

          if ex?
            writeFlag = app.config.get("no_writehistory") is "off"
            if ex.kind is "own"
              if writeFlag
                app.WriteHistory.add(ex.thread_url, 1, ex.title, ex.name, ex.mail, ex.name, ex.mail, ex.mes, Date.now().valueOf())
              app.message.send("open", url: ex.thread_url, new_tab: true)
            else
              for thread in board
                if thread.title.includes(ex.title)
                  if writeFlag
                    app.WriteHistory.add(thread.url, 1, ex.title, ex.name, ex.mail, ex.name, ex.mail, ex.mes, thread.created_at)
                  app.message.send("open", url: thread.url, new_tab: true)
                  break

          tableSorter.update()
          return

        .catch ->
          return
        .then ->
          $view.removeClass("loading")

          if $table.hasClass("table_search")
            $view.C("searchbox")[0].dispatchEvent(new Event("input"))

          $view.dispatchEvent(new Event("view_loaded"))

          $button = $view.C("button_reload")[0]
          $button.addClass("disabled")
          setTimeout((-> $button.removeClass("disabled")), 1000 * 5)
          return
      return
    , 150)
    return

  $view.on "request_reload", (e) ->
    return if $view.hasClass("loading")
    return if $view.C("button_reload")[0].hasClass("disabled")
    load(e.detail)
    return
  load()
  return
