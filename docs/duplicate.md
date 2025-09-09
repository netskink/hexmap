
# start with bash and finder

```
$ cd apps
$ ditto old_Prj new_prj
$ cd new_prj
$ mv old_prj.xcodeproj new_prj.xcodeproj
```

Use finder to drag the new_prj.xcodeproj into the workspace.


# open the new proj in xcode

1. product->scheme->manage scheme
  * rename to new_prj
2. project file->"app" target->general tab->identity->bundle identifier
  a. click the arrow to right
  b. rename
3. expand the app in sidebar and rename the app/group
4. Manage the scheme again.  This time click edit.  Select the executable for the Run target.
5. SceneXXX.sks objects will have to be repointed for the module in right side attributes.
