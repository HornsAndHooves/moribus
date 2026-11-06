# Moribus

[![Build Status](https://secure.travis-ci.org/HornsAndHooves/moribus.png)](http://travis-ci.org/HornsAndHooves/moribus)

Moribus is a set of tools for managing complex graphs of ActiveRecord objects
for which there are many inbound foreign keys, attributes and associations with
high rates of change, and business demands for well-tracked change history.

## AggregatedBehavior

AggregatedBehavior implements a pattern in which an object's identity
is modeled apart from its attributes and outbound associations. This enables
a higher level of normalization of your data, since one set of properties
may be shared among multiple objects. This set of properties - attributes
and outbound associations - are modeled on an object called an "info object".
And we say that this info object is aggregated by host object(s) and it acts
(behaves) as aggregated. When an aggregated object is about to be saved, it
looks up for an existing record with the same attributes in the database under
the hood, and if it is found, it 'replaces' itself with that record. This allows
you to work with attributes of your entity as if they are properties of an
actual model and normalize your data at the same time.

Inbound foreign keys will always point at the same object in memory, and the
object will never be stale, as it has no attributes of its own that are subject
to change. This is useful for objects with many inbound foreign keys and
high-traffic attributes/associations, such as statuses. Without this pattern
it would be difficult to avoid many StaleObjectErrors.

## TrackedBehavior

TrackedBehavior implements history tracking on the stack of objects
representing the identity object's attributes and outbound associations.
When a model behaves as a tracked behavior, it will never actually get
updated. Instead, it will update it's own 'is_current' column to false
and will be saved as a new record with new attribute values and the
'is_current' column as 'true'. Thus, under the hood, new attributes
will supersede old attributes, leaving the old record as historical.

When using `acts_as_tracked by: :association`, parent foreign keys are resolved
when needed, so the association may be declared before or after `acts_as_tracked`.
Subclasses inherit the parent association configuration unless they override it.

## Macros, Associations and Combination

Despite the fact that Moribus may be used by models on its own,
its main purpose is to be used within associations, and in conjunction
with associations.  The best way to demonstrate this is by example.

Let's assume we have a User entity with attributes that should be tracked
and normalized. Those attributes may be, for example, `:first_name`,
`:last_name` and `:status` as enumerated integer value. This entity
may be represented with three models: `User` - with main model for interactions,
tracked `UserInfo` (`user_id`, `person_name_id`, `status`) for tracking, and
aggregated `UserName` (`first_name`, `last_name`) for name normalization.
Class definitions for these models will appear as follows:

```ruby
  class User < ActiveRecord::Base
    has_one_current :user_info
    delegate_associated :user_name, :to => :user_info
  end

  class UserInfo < ActiveRecord::Base
    has_aggregated :person_name
    acts_as_tracked
  end

  class UserName < ActiveRecord::Base
    acts_as_aggregated
  end
```

Despite the fact that internal representation is more complicated now,
top-level operations will look exactly the same:

```ruby
  user = User.create(:first_name => 'John', :last_name => 'Smith', :status => 0)
  # This creates User(id: 1) record, PersonName(id: 1, first_name: 'John', last_name: 'Smith')
  # record and UserInfo(id: 1, user_id: 1, person_name_id: 1, status: 0, is_current: true)

  user.update_attributes(:status => 1)
  # This creates new UserInfo(id: 2, user_id: 1, person_name_id: 1, status: 1, is_current: true)
  # record, and changes UserInfo(id: 1) record's 'is_current' attribute to false.

  user.update_attributes(:first_name => 'Mike')
  # This creates new PersonName(id: 2, first_name: 'Mike', last_name: 'Smith') record and new
  # current UserInfo(id: 3, user_id: 1, person_name_id: 2, :status: 1, is_current: true)

  # Now, if we want to create another 'John Smith' user:
  user2 = User.create(:first_name => 'John', :last_name => 'Smith', :status => 5)
  # This creates User(id: 2) record and UserInfo(id: 4, user_id: 2, person_name_id: 1, status: 5, is_current: true)
  # record that reuses existing UserName information.
```

## Use it

    gem 'HornsAndHooves-moribus', require: 'moribus'

## Run tests

```sh
rake spec
```

## Credits

* [Artem Kuzko](https://github.com/akuzko)
* [Potapov Sergey](https://github.com/greyblake)

## Copyright

Copyright (c) 2014-2018 HornsAndHooves.

Copyright (c) 2013 TMX Credit.
