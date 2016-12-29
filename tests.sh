#!/bin/bash

. lib.sh


function test_hasvalue_positive()
{
	SOMEVALUE='aaa'
	has_value SOMEVALUE
	[ $? -eq 0 ] && return 0
	return 1
}

function test_hasvalue_negative()
{
	unset NOVALUE
	has_value NOVALUE
	[ $? -eq 1 ] && return 0
	return 1
}

function test_is_integer_positive()
{
    let -i INT=1
    is_integer INT
	[ $? -eq 0 ] && return 0
	return 1
}

function test_is_integer_negative()
{
    LETTER=abc
    is_integer LETTER
	[ $? -eq 1 ] && return 0
	return 1
}


function run_tests()
{
  local SUCCESS_TESTS=0
  local FAILED_TESTS=0

  TESTS=$(compgen -A function)
  
  for I in $TESTS; 
  do
    if [[ "$I" =~ ^test_ ]]; then
      TESTNAME=${I%^test_}
      echo -n "Test '$TESTNAME'"
      if $I; then
        SUCCESS_TESTS=$((SUCCESS_TESTS + 1))
        echo " OK"
      else
        FAILED_TESTS=$((SUCCESS_TESTS + 1))
        echo " FAIL"
      fi
    fi
  done

  TOTAL=$((SUCCESS_TESTS + FAILED_TESTS))
  echo "Performed $TOTAL tests"
  echo "$SUCCESS_TESTS successfull, $FAILED_TESTS failed"
  return $FAILED_TESTS 
}

run_tests

# vim: set ts=4 sw=4 et :
