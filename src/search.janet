(def sep
  (if (= :windows (os/which))
    `\`
    "/"))

(defn find-files
  [dir &opt pred]
  (default pred identity)
  (def paths @[])
  (defn helper
    [a-dir]
    (each path (os/dir a-dir)
      (def sub-path
        (string a-dir sep path))
      (case (os/stat sub-path :mode)
        :directory
        (when (not= path ".git")
          (when (not (os/stat (string sub-path sep ".gitrepo")))
            (helper sub-path)))
        #
        :file
        (when (pred sub-path)
          (array/push paths sub-path)))))
  (helper dir)
  paths)

(comment

  (find-files "." |(string/has-suffix? ".janet" $))

  )

(defn clean-end-of-path
  [path a-sep]
  (when (one? (length path))
    (break path))
  (if (string/has-suffix? a-sep path)
    (string/slice path 0 -2)
    path))

(comment

  (clean-end-of-path "hello/" "/")
  # =>
  "hello"

  (clean-end-of-path "/" "/")
  # =>
  "/"

  )

(defn has-janet-shebang?
  [path]
  (with [f (file/open path)]
    (def first-line (file/read f :line))
    (when first-line
      (and (string/find "env" first-line)
           (string/find "janet" first-line)))))

(defn collect-paths
  [includes &opt pred]
  (default pred identity)
  (def filepaths @[])
  # collect file and directory paths
  (each thing includes
    (def apath (clean-end-of-path thing sep))
    (def mode (os/stat apath :mode))
    # XXX: should :link be supported?
    (cond
      (= :file mode)
      (array/push filepaths apath)
      #
      (= :directory mode)
      (array/concat filepaths (find-files apath pred))
      #
      (do
        (eprintf "No such file or not an ordinary file or directory: %s"
                 apath)
        (os/exit 1))))
  #
  filepaths)

(defn search-paths
  [query-fn opts]
  (def {:name name :paths src-paths} opts)
  #
  (def all-results @[])
  (def hit-paths @[])
  (each path src-paths
    (def src (slurp path))
    (when (pos? (length src))
      (when (or (not name)
                (string/find name src))
        (array/push hit-paths path)
        (def results
          (try
            (query-fn src opts)
            ([e]
              (eprintf "search failed for: %s" path))))
        (when (and results (not (empty? results)))
          (each item results
            (array/push all-results (merge item {:path path})))))))
  #
  [all-results hit-paths])

