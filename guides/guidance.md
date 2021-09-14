# General Guidance

## Top-down or Bottom-up?

In my experience when you already have an idea of what it is you want to parse there is a temptation to start at the top and work down. Whenever I do this I seem to run into trouble with something that doesn't fit together right or parsing issues that I then find hard to track down.

My experience is that it's easiest to work bottom up. Parse small actual pieces of the language you want to parse and join these together, building towards the whole format. In general I tend to find I hit parsing errors quicker and can resolve them more easily this way.

While you might have a different experience my advice, if you don't have an opinion yet, is to build your parser bottom up.
