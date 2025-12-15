(defn a/parse-args
  [args]
  (def the-args (array ;args))
  #
  (def head (get the-args 0))
  #
  (def conf-file ".jeat.janet")
  #
  (when (or (= head "-h") (= head "--help")
            # might have been invoked with no paths in repository root
            (and (not head)
                 (not= :file (os/stat conf-file :mode))))
    (break @{:help true}))
  #
  (def opts
    (if head
      (if-not (and (string/has-prefix? "{" head)
                   (string/has-suffix? "}" head))
        @{}
        (let [parsed
              (try (parse (string "@" head))
                ([e] (eprint e)
                     (errorf "failed to parse options: %n" head)))]
          (assertf (and parsed (table? parsed))
                   "expected table but found: %s" (type parsed))
          (array/remove the-args 0)
          parsed))
      @{}))
  #
  (defn get-in-ex
    [req-path]
    (let [conf-env (try (require req-path)
                     ([e] (error e)))
          conf ((get-in conf-env ['init :value]))]
      (assertf conf "missing init function in .jeat.janet")
      #
      [(get conf :jeat-target-spec @[])
       (get conf :jeat-exclude-spec @[])]))
  #
  (def [includes excludes]
    (cond
      # jpm test, jeep test, etc.
      (get opts :via-test-trigger)
      (get-in-ex "../.jeat")
      # paths on command line take precedence over conf file
      (not (empty? the-args))
      [the-args @[]]
      # conf file in working dir?
      (= :file (os/stat conf-file :mode))
      (get-in-ex "/.jeat") # working directory import
      #
      (errorf "unexpected result parsing: %n" args)))
  #
  (merge opts
         {:includes includes
          :excludes excludes}))

