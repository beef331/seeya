task genHeaders, "generates the headers":
  selfExec("c -d:genHeader -f --verbosity:0 -c seeya.nim")
  selfExec("c -d:genHeader -f --verbosity:0 -c tests/mylib.nim")

task test, "runs the test":
  genHeadersTask()
  selfExec("c --app:lib --verbosity:0 tests/mylib.nim")
  exec("gcc -L./tests/ -lmylib tests/test.c")
  putEnv("LD_LIBRARY_PATH", "./tests")
  exec("./a.out")
