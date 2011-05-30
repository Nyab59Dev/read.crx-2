`/** @namespace */`
app.cache = {}

(->
  app.cache._db_open = $.Deferred (deferred) ->
    req = webkitIndexedDB.open("cache")
    req.onerror = ->
      deferred.reject()
      app.log("error", "app.cache: db.open失敗")
    req.onsuccess = ->
      deferred.resolve(req.result)

  .pipe (db) ->
    $.Deferred (deferred) ->
      if db.version is "1"
        deferred.resolve(db)
      else
        req = db.setVersion("1")
        req.onerror = ->
          app.log("error", "app.cache: db.setVersion失敗(#{db.version} -> 1)")
          deferred.reject(db)
        req.onsuccess = (e) ->
          db.createObjectStore("cache", keyPath: "url")
          app.log("info", "app.cache: db.setVersion成功(#{db.version} -> 1)")
          deferred.resolve(db)

  .fail (db) -> db and db.close()

  .promise()
)()

app.cache.get = (url) ->
  app.cache._db_open

    .pipe (db) ->
      $.Deferred (deferred) ->
        objectStore = db.transaction(["cache"]).objectStore("cache")

        req = objectStore.get(url)
        req.onsuccess = () ->
          if typeof req.result is "object"
            deferred.resolve(status: "success", data: req.result)
          else
            deferred.reject(status: "not_found")
        req.onerror = ->
          app.log("error", "app.cache.get: キャッシュの取得に失敗")
          deferred.reject(status: "error")
    , ->
      $.Deferred (deferred) ->
        deferred.reject(status: "error")

    .promise()

app.cache.set = (data) ->
  if (
    typeof data.url isnt "string" or
    typeof data.data isnt "string" or
    typeof data.last_modified isnt "number" or
    typeof data.last_updated isnt "number"
  )
    app.log("error", "app.cache.set: 引数が不正です", arguments)
    return $.Deferred().reject().promise()

  app.cache._db_open

    .pipe (db) ->
      $.Deferred (deferred) ->
        transaction = db.transaction(["cache"], webkitIDBTransaction.READ_WRITE)
        transaction.oncomplete = ->
          deferred.resolve(db)
        transaction.onerror = ->
          deferred.reject()

        transaction.objectStore("cache").put(data)

    .promise()

app.cache.remove = (url) ->
  app.cache._db_open

    .pipe (db) ->
      $.Deferred (deferred) ->
        transaction = db.transaction(["cache"], webkitIDBTransaction.READ_WRITE)
        transaction.oncomplete = ->
          deferred.resolve()
        transaction.onerror = ->
          deferred.reject()

        transaction.objectStore("cache").delete(url)

    .promise()