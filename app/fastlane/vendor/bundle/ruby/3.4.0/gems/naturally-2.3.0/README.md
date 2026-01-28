# Naturally
[![Gem Version](https://badge.fury.io/rb/naturally.svg)](https://badge.fury.io/rb/naturally)

Natural ("version number") sorting with support for:

* **legal document numbering**,
* **college course codes**, and
* **Unicode**.

See Jeff Atwood's [Sorting for Humans: Natural Sort Order](https://blog.codinghorror.com/sorting-for-humans-natural-sort-order/) and my post [Counting to 10 in Californian](https://blog.public.law/2012/08/07/counting-from-1-to-10-in-californian/).

## Installation

```Shell
$ gem install naturally
```

## Usage

```Ruby
require 'naturally'

# Sort a simple array of strings with legal numbering
Naturally.sort(["336", "335a", "335", "335.1"])  # => ["335", "335.1", "335a", "336"]

# Sort version numbers
Naturally.sort(["13.10", "13.04", "10.10", "10.04.4"])  # => ["10.04.4", "10.10", "13.04", "13.10"]
```

Usually the library is used to sort an array of objects:


```Ruby
# Define a new simple object for storing Ubuntu versions
UbuntuVersion = Struct.new(:name, :version)

# Create an array
releases = [
  UbuntuVersion.new('Saucy Salamander', '13.10'),
  UbuntuVersion.new('Raring Ringtail',  '13.04'),
  UbuntuVersion.new('Precise Pangolin', '12.04.4'),
  UbuntuVersion.new('Maverick Meerkat', '10.10'),
  UbuntuVersion.new('Quantal Quetzal',  '12.10'),
  UbuntuVersion.new('Lucid Lynx',       '10.04.4')
]

# Sort by version number
sorted = Naturally.sort(releases, by: :version)

# Check what we have
expect(sorted.map(&:name)).to eq [
  'Lucid Lynx',
  'Maverick Meerkat',
  'Precise Pangolin',
  'Quantal Quetzal',
  'Raring Ringtail',
  'Saucy Salamander'
]
```

[More examples are in the specs](https://github.com/public-law/naturally/blob/master/spec/naturally_spec.rb).


## `#sort_filenames`

Sorts filenames naturally, treating underscores and dots as separators. Useful for sorting files like images or documents that use numbers, underscores, and dots in their names.

```ruby
files = [
  'abc_2.tif',
  'abc_1_a.tif',
  'abc_1.zzz',
  'abc_1_xyz.abc',
  'abc_2a.tif',
  'abc.2.tif',
  'abc.1_a.tif',
  'abc_2.abc',
  'abc_1_xyz.abc'
]
Naturally.sort_filenames(files)
# => [
#   "abc.1_a.tif",
#   "abc.2.tif",
#   "abc_1.zzz",
#   "abc_1_a.tif",
#   "abc_1_xyz.abc",
#   "abc_1_xyz.abc",
#   "abc_2.abc",
#   "abc_2.tif",
#   "abc_2a.tif"
# ]
```

This method gives higher priority to dots than underscores, so files like `abc.1_a.tif` will come before `abc.2.tif`.


## Implementation Notes

The algorithm capitalizes on Ruby's array comparison behavior:
Since each dotted number actually represents a hierarchical 
identifier, [array comparison](http://ruby-doc.org/core-2.2.1/Array.html#method-i-3C-3D-3E) 
is a natural fit:

> Arrays are compared in an “element-wise” manner; the first element of ary is compared with the first one of other_ary using the <=> operator, then each of the second elements, etc… As soon as the result of any such comparison is non zero (i.e. the two corresponding elements are not equal), that result is returned for the whole array comparison.


And so, when given input such as,

```ruby
['1.9', '1.9a', '1.10']
```

...this module sorts the segmented numbers 
by comparing them in their array forms:

```ruby
[['1', '9'], ['1', '9a'], ['1', '10']]
```

Finally, upon actual sort comparison, each of these strings is 
converted to an array of typed objects. This is to determine the 
sort order between heterogenous (yet ordered) segments such as 
`'9a'` and `'9'`.

The final nested comparison structure looks like this:

```ruby
  [
   [
     [1], [9]
   ],
   [
     [1], [9, 'a']
   ],
   [
     [1], [10]
   ]
  ]
```

## Related Work

* [ahoward/version_sorter](https://github.com/ahoward/version_sorter), the starting point for the `naturally` gem.
* [GitHub's Version sorter](https://github.com/github/version_sorter)


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
