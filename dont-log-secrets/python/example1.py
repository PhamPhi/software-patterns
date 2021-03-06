#!/usr/bin/env python

import json
from json import JSONEncoder

# Hide a secret value from loggers and json encoders.
# This is to prevent accidental exposure of password fields.
#
# To get the value of this secret, call secret.value()
# Otherwise, repr() and str() on these objects will return
# simply "<secret>"
class Secret(object):
  def __init__(self, value):
    # Define a method to hide the value. This uses the
    # technique described here:
    # https://github.com/jordansissel/software-patterns/blob/master/dont-log-secrets/ruby/README.md#implementation-2-hiding-the-instance-variable
    def valuefunc():
      return value
    self.value = valuefunc

  def __repr__(self):
    return "<secret>"

  def __str__(self):
    return repr(self)
    
# Provide a custom 'default' encoder method to cover 
# objects of type 'Secret'
jsenc = JSONEncoder()
def secretjson(obj):
  if isinstance(obj, Secret):
    return repr(obj)
  return jsenc.default(obj)


params = {
  "q": "hello world",
  "user": "jordan",
  "password": "nobody will guess me"
}

# Override the 'password' param as a Secret.
# this would be common if you get your params from wsgi, for example.
params["password"] = Secret(params["password"])

print "str(): %s" % params["password"]
print "repr(): %r" % repr(params["password"])
print ".value(): %s" % params["password"].value()
print "json.dumps(): %s" % json.dumps(params, default=secretjson)
