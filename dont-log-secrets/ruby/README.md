# Preventing Accidental Secret Leaks

Application logs are often riddled with passwords. Oops, right?

Your 'User' model might have a password field, and you might just do this:
```
  logger.info(user)
```

Oops. You just leaked the password value if it is an instance variable.

## Goal

The goal here is not to prevent malicious activity, but to prevent accidental
activity, such as logging, from exposing secret information.

## Implementation 1: Wrapping a value.

In this implementation, I simply use a class to wrap a value. The class
provides `to_s` and `inspect` methods to prevent accidental exposure.

The goal is to prevent any unintentional access to the secret value. To that
end, we want to make any intentional access quite explicit. In this case, you
must call `Secret#value` in order to get the original value.

See [secret.rb](???) for the class definition.

This was written based on recognition that loggers, printing, and object
inspection can often reveal internals of an object you would prefer
not having exposed.

Example use:

```
#<User:0x000000009d4ae0 @name="jordan", @password=<secret>>
I, [2012-06-08T13:41:30.216136 #13346]  INFO -- : #<User:0x000000009d4ae0 @name="jordan", @password=<secret>>
```

As you can see above, we hide the password in both cases.

There are more powerful inspection tools, like awesome_print, that will leak
your secrets, though.

```
>> ap jordan
#<User:0x0170be98
  attr_accessor :name = "jordan",
  attr_accessor :password = #<Secret:0x0170be70
    attr_reader :value = "my password"
  >
>
```

We'll need to fix this.

## Implementation 2: Hiding the instance variable

Instead of using an instance variable, just define a method that returns the value.

See [lib/secret2.rb]

```
% ruby example2.rb
I, [2012-06-08T14:03:17.685723 #13914]  INFO -- : #<User:0x00000001010d78 @name="jordan", @password=<secret>>
#<User:0x01010d78
  attr_accessor :name = "jordan",
  attr_accessor :password = <secret>
>
The secret: my password
```

Now above, you see all 3 cases the secret is hidden, but still accessible if I
am explicit in asking for the secret value.
