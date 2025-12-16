#! /usr/bin/env janet

(import ./args :as a)
(import ./search :as s)
(import ./rewrite :as r)
(import ./utils :as u)

###########################################################################

(def test-file-ext ".jeat")

(defn make-tests
  [filepath]
  (def src (slurp filepath))
  (def test-src (r/rewrite-as-test-file src))
  (unless test-src
    (break :no-tests))
  #
  (def [fdir fname] (u/parse-path filepath))
  (def test-filepath (string fdir "_" fname test-file-ext))
  (when (os/stat test-filepath :mode)
    (eprintf "test file already exists for: %p" filepath)
    (break nil))
  #
  (spit test-filepath test-src)
  #
  test-filepath)

(defn run-tests
  [test-filepath]
  (try
    (with [of (file/temp)]
      (with [ef (file/temp)]
        (let [cmd 
              # prevents any contained `main` functions from executing
              ["janet" "-e" (string "(dofile `" test-filepath "`)")]
              ecode (os/execute cmd :p {:out of :err ef})]
          (when (not (zero? ecode))
            (eprintf "non-zero exit code: %p" ecode))
          #
          (file/flush of)
          (file/flush ef)
          (file/seek of :set 0)
          (file/seek ef :set 0)
          #
          [(file/read of :all)
           (file/read ef :all)
           ecode])))
    ([e]
      (eprintf "problem executing tests: %p" e)
      [nil nil nil])))

(defn report
  [out err]
  (when (and out (pos? (length out)))
    (print out)
    (print))
  (when (and err (pos? (length err)))
    (print "------")
    (print "stderr")
    (print "------")
    (print err)
    (print))
  # XXX: kind of awkward
  (when (and (empty? out) (empty? err))
    (print "no test output...possibly no tests")
    (print)))

(defn make-run-report
  [filepath]
  # create test source
  (def result (make-tests filepath))
  (unless result
    (eprintf "failed to create test file for: %p" filepath)
    (break nil))
  #
  (when (= :no-tests result)
    (break :no-tests))
  #
  (def test-filepath result)
  # run tests and collect output
  (def [out err ecode] (run-tests test-filepath))
  # print out results
  (report out err)
  # finish off
  (when (zero? ecode)
    (os/rm test-filepath)
    true))

########################################################################

(defn main
  [_ & args]
  (def opts (a/parse-args args))
  #
  (def includes (get opts :includes))
  (def excludes (get opts :excludes))
  #
  (def src-filepaths
    (s/collect-paths includes |(or (string/has-suffix? ".janet" $)
                                   (s/has-janet-shebang? $))))
  # generate tests, run tests, and report
  (each path src-filepaths
    (when (and (not (has-value? excludes path))
               (= :file (os/stat path :mode)))
      (print path)
      (def result (make-run-report path))
      (cond
        (= :no-tests result)
        # XXX: the 2 newlines here are cosmetic
        (eprintf "* no tests detected for: %p\n\n" path)
        #
        (nil? result)
        (do
          (eprintf "failure in: %p" path)
          (os/exit 1))
        #
        (true? result)
        true
        #
        (do
          (eprintf "Unexpected result %p for: %p" result path)
          (os/exit 1)))))
  (printf "All tests completed successfully in %d file(s)."
          (length src-filepaths)))

