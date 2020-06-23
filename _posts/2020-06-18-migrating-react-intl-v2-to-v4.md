---
layout: post
title:  "Migrating react-intl from v2 to v4"
date:   2020-06-19 23:34:23 +0200
categories: react
tags: react react-intl
---
I took the liberty upon myself to upgrade `react-intl` at work from `2.8.0` to the latest (as of writing) `4.6.9`. The journey of going through all the hoops wasn't all well documented, although they do have a guide on [migrating from v2 to v3](https://formatjs.io/docs/react-intl/upgrade-guide-3x/) but I found it not being enough, then we've got [migrating from v3 to v4](https://formatjs.io/docs/react-intl/upgrade-guide-4x) which held better information though the change wasn't as big as going from v2 to v3.

When upgrading I took one major version at a time, so rather than jumping from `2.x` straight to `4.x` I went from `2.x` to `3.x` to tackle the biggest changes first and later on see what the jump from `3.x` to `4.x` would entail.

## Table of Contents
- [Upgrading 2.x to 3.2.4](#upgrading-2x-to-324)
  - [Use full-icu](#use-full-icu)
  - [Polyfill](#polyfill)
  - [Configure `webpack`](#configure-webpack)
  - [Configure `jest`](#configure-jest)
  - [Testing](#testing)
    - [Enzyme helper functions](#enzyme-helper-functions)
    - [Mocking time](#mocking-time)
  - [Adapt codebase](#adapt-codebase-post-upgrade)
  - [Old FormattedRelativeTime behaviour](#old-formattedrelativetime-behaviour)
- [Upgrading 3.2.4 to 3.12.1](#upgrading-324-to-3121)
- [Upgrading 3.12.1 to ^4.6.9](#upgrading-3121-to-469)
  - [Renaming `FormattedHTMLMessage` & `formatHTMLMessage`](#renaming-formattedhtmlmessage--formathtmlmessage)
  - [Add corresponding functions to tags](#add-corresponding-functions-to-tags)
- [Finally](#finally)

### Upgrading 2.x to 3.2.4

> I specifically chose the exact version 3.2.4 because the previous versions were either lacking necessary functionality or contained bugs
{:.warning}

I've tried to break up the steps I had to take to have linting and tests passing before I would move onto v4.

This upgrade was the most tedious one as they moved from their own libraries to the more stable native APIs. The specs they had first used to do their implementations became outdated and had changed since. With the new more stable API also introduced some limitations which had to be taken into account when refactoring. This means that the way e.g. relative dates were formatted would no longer work the same as in v2, see [Old FormattedRelativeTime behaviour](#old-formattedrelativetime-behaviour).

Breaking changes:

- `addLocaleData` was removed
- `ReactIntlLocaleData` was removed
- `intlShape` was removed
- `IntlProvider`'s default text component changed from `span` to `React.Fragment`
- `FormattedRelative` renamed to `FormattedRelativeTime`
- `formatRelative` renamed to `formatRelativeTime`
- ... to name a few, rest can be read in the [migration guide from v2 to v3](https://formatjs.io/docs/react-intl/upgrade-guide-3x/)

#### Use full-icu

Unless you want to compile Node.js with `full-icu` ([instructions here](https://nodejs.org/api/intl.html)), you could instead make use of the [`full-icu`](https://www.npmjs.com/package/full-icu) npm package, like so:

```bash
# To initialize Node with the full-icu package
NODE_ICU_DATA=node_modules/full-icu yarn test
```

#### Polyfill

Also if you support older browsers, e.g. IE11, Safari 12, Edge etc.. you'd need to polyfill for those.

```javascript
// Polyfill e.g IE11 & Safari 12-
if (!Intl.PluralRules) {
  require('@formatjs/intl-pluralrules/polyfill');
  // Add locale data for sv
  require('@formatjs/intl-pluralrules/dist/locale-data/sv');
}

// Polyfill e.g IE11, Edge, Safari 13-
if (!Intl.RelativeTimeFormat) {
  require('@formatjs/intl-relativetimeformat/polyfill');
  // Add locale data for sv
  require('@formatjs/intl-relativetimeformat/dist/locale-data/sv');
}
```

#### Configure webpack

Because we're using `webpack` to bundle our projects we had to make changes to our `webpack` config:
- Per [their comment about using `webpack` and `babel-loader`](https://formatjs.io/docs/react-intl/upgrade-guide-3x/#webpack), transpile the following packages, however only through our production config:

    ```diff
   ...
   include: [
     ...
  +  path.join(__dirname, "node_modules/react-intl"),
  +  path.join(__dirname, "node_modules/intl-messageformat"),
  +  path.join(__dirname, "node_modules/intl-messageformat-parser"),
   ],
    ```

#### Configure Jest

Since we're using `jest` we should also avoid transforming certain libraries, [again per their comment](#https://formatjs.io/docs/react-intl/upgrade-guide-3x/#jest)

```javascript
{
  transformIgnorePatterns: [
    '/node_modules/(?!intl-messageformat|intl-messageformat-parser).+\\.js$',
  ],
}
```

#### Testing

A more complete section about [testing with `react-intl` can be read here](https://formatjs.io/docs/react-intl/testing/)

##### Enzyme helper functions

We already had similar helper functions like described [here](https://formatjs.io/docs/react-intl/testing/#helper-function-1) with both `mountWithIntl` and `shallowWithIntl`. However previously the `intl` prop would be accessed either through a prop or the context, with the release of v3 they moved over to the new React Context API, meaning we should be passing it down differently now.

```javascript
 /* Redacted version of the code */
 import {
   IntlProvider,
   createIntl,
   createIntlCache,
 } from 'react-intl';

 const cache = createIntlCache();
 const intl = createIntl({
   locale: 'sv',
   defaultLocale: 'sv',
   defaultFormats: INTL_FORMATS,
   formats: INTL_FORMATS,
   textComponent: 'span',
 }, cache);

 export function mountWithIntl(node) {
   return mount(node, {
     wrappingComponent: IntlProvider,
     wrappingComponentProps: intl,
   });
 }

 export function shallowWithIntl(node) {
  return shallow(node, {
    wrappingComponent: IntlProvider,
    wrappingComponentProps: intl,,
  });
}
```

##### Mocking time

In v2 it was enough to mock the `Date` constructor, in v3 they started relying on `Date.now()` instead.

```javascript
// mock it like so
Date.now = jest.fn(() => 1487076708000) // 14.02.2017
// or
Date.now = jest.fn(() => new Date(Date.UTC(2017, 1, 14)).valueOf())
// or
global.Date.now = (date) => +new Date(date);
```

preferrably turned into a utility function.

#### Adapt codebase post upgrade

Dealing with the removal of `addLocaleData` and the change of default component from `span` to `React.Fragment`. The reason for switching back to the old behaviour is to avoid noise in snapshot changes as my guess is that there would be other more important things to look out for.

```diff
- import { addLocaleData, IntlProvider } from 'react-intl';
+ import { IntlProvider } from 'react-intl';
 ...
- addLocaleData(currentLocale.localeData);	
 ...
 return (
   <IntlProvider
+   textComponent="span"    
   />
 );
```

however the snapshots would get updated with the following addition

```diff
 <FormattedHTMLMessage
   id="message.id.here"
   defaultMessage="..."
+  tagName="span"
 />
```

if you're using `injectIntl` you can also expect snapshots to get updated with a very minimal change, note the lowercase i in "Inject"

```diff
- <InjectIntl(SomeComponent) />
+ <injectIntl(SomeComponent) />
```

Renaming `FormattedRelative` component to  `FormattedRelativeTime` and `formatRelative` function to `formatRelativeTime`, this will also result in snapshots getting updated with expected name changes.

If you're passing the `intl` object to a component the snapshots would also introduce several new (expected ones if you'd look at their changelog) properties.

_The properties not changed (does not have a - or + in the beginning of the line) is just to provide some context_

```diff
 <SomeComponent
   intl={
    Object {
      "locale": "sv",
      "defaultLocale": "sv",
      "formatDate": [Function],
      ...
+     "formatDateToParts": [Function],
+     "formatNumbersToParts": [Function],
+     "formatTimeToParts": [Function],
      "formats": Object {
        ...
+       "getPluralRules": [Function],
+       "getRelativeTimeFormat": [Function],
      },
-     "timeZone": null,
+     "timeZone": undefined,
    }
   }
 />
```

Other than the above mentioned changes in our snapshots, you might also see corrected snapshots if you previously hadn't compiled Node with full-icu or used the `full-icu` npm package, as per default Node is only compiled with `en`. In our case we hadn't done any of the above and so with the `full-icu` npm package in place we started seeing e.g. months changing:

```diff
- May
+ Maj
```

which is the correct spelling of "May" in Swedish.

##### Old FormattedRelativeTime behaviour

I found [this GitHub issue](https://github.com/formatjs/formatjs/issues/1397) which talks about how the output has changed, which is due to the new API limitations as I understood it. The team behind `react-intl` being aware of this created `@formatjs/intl-utils` to make the transition smoother. In the same GitHub issue there are two comments on how to tackle this problem, however I stuck with the [second comment](https://github.com/formatjs/formatjs/issues/1397#issuecomment-521025227).

One thing I noticed, which I'm not sure if it's a bug or not. If you have the current date being `2019-04-25` and you would like to know in a human readable form how long it's until `2019-05-01`, it would tell you `1 month`.

Looking at their source code for [`@formatjs/intl-utils@3.3.1`](https://github.com/formatjs/formatjs/blob/%40formatjs/intl-utils%403.3.1/packages/intl-utils/src/diff.ts#L66-L78) we see this:

```typescript
export function selectUnit(...) {
  ...

  const months = years * 12 + fromDate.getMonth() - toDate.getMonth();
  if (Math.round(Math.abs(months)) > 0) {
    return {
      value: Math.round(months),
      unit: 'month',
    };
  }
  const weeks = secs / SECS_PER_WEEK;

  return {
    value: Math.round(weeks),
    unit: 'week',
  };
}
```

they first look at the months which clearly tells me why I get `1 month` rather than `6 days`. To workaround this issue I did the following (adding on top of the [second comment from above GitHub issue](https://github.com/formatjs/formatjs/issues/1397#issuecomment-521025227)):

```javascript
export function formattedRelative(...) {
  if (!value) {
    return undefined;
  }

  const { value: selectedValue, unit } = selectUnit(
    new Date(value),
    undefined,
    {
      day: 30,
      quarter: false,
    },
  );

  if (selectedValue > 6 && selectedValue < 30) {
    const weeks = Math.round(selectedValue / 7);
    return intl.formatRelativeTime(weeks, 'week', options);
  }

  return intl.formatRelativeTime(selectedValue, unit, options);
}
```

and as you can see I increase the threshold for days, before they are considered weeks. This to make sure we don't fall into the month if-statement and we get back X days, so that we later divide it by 7 and pass the unit `week` right away. If days are more than `30` we can start considering showing months instead.

### Upgrading 3.2.4 to 3.12.1

Once tests were passing at `react-intl@3.2.4` I moved closer to the next major release, by upgrading to the latest 3.x version this time.

Very minor changes, few new functions were added which the snapshots would reflect.

```diff
 <SomeComponent
   intl={
    Object {
      "locale": "sv",
      "defaultLocale": "sv",
      "formatDate": [Function],
      "formatDateToParts": [Function],
      "formatNumbersToParts": [Function],
      "formatTimeToParts": [Function],
+     "formatDisplayName": [Function],
+     "formatList": [Function],
      ...
      "formats": Object {
        ...
      },
      "formatters": Object {
        ...
+       "getDisplayNames": [Function],
+       "getListFormat": [Function],
      },
    }
   }
 />
```

### Upgrading 3.12.1 to ^4.6.9

#### Renaming `FormattedHTMLMessage` & `formatHTMLMessage`

Since v2 the `FormattedMessage` component and `formatMessage` function has grown to become the "go-to" guy for all needs. It's now able to parse HTML, making the respective component `FormattedHTMLMessage` and function `formatHTMLMessage` obsolete, so they've been removed.

Feel free to rename any occurrences of `FormattedHTMLMessage` to `FormattedMessage` and the function `formatHTMLMessage` to `formatMessage`.

#### Add corresponding functions to tags

`react-intl` will shout errors if tags are used in messages without having a corresponding function.

```diff
 <FormattedMessage
   id="message.id.here"
   defaultMessage="Hello, <b>{name}</b>"
   values={
     name: 'foo',
+    b: (...chunks) => <strong>{chunks}</strong>,
   }
 />
```

#### Finally

It took me a while to figure everything out, perhaps I'm not the brightest either.. but I had to debug the source code of `react-intl` and related packages when something wouldn't play well or work at all. As the API documentation wouldn't fully go over what properties components could take or what arguments could be passed to helper functions and how that might alter the result.
