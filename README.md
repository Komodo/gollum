Much of the [gollum readme](https://github.com/gollum/gollum/blob/master/README.md) still holds true here.

kollum is only intended to be used for the Komodo docs, of course you are free to fork (as per the license) and use it for your own purposes, but that's not the explicit intend of this project.

The biggest differences between kollum and gollum are:

 * omnigollum built-in
 * integreated (and heavily modified) the [breadcrumbs PR](https://github.com/gollum/gollum/pull/902) by @aspyct
 * Templates completely overhauled, using Foundation CSS
   * They are very much biased towards Komodo. It will literally say "Komodo IDE" in there.

Todo:

 * Private routes
 * Separate the templates, css and views into their own repo
 * Built in versioning, ie. a dropdown letting users quickly access a previous version of a page (a version is not a commit, it's much more explicit than that)
