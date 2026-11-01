# JNI contract headers

These headers are the **contract** between the Java module and this C core:

- `project_NativePhase1.h` — `project.NativePhase1.coreVersion()`
- `project_NativePhase2.h` — `project.NativePhase2.*` (gradeScanNative / scanOpen / scanBand / scanClose / gradeIntsPerHit / coreVersion)

They are generated with `javac -h` from the Java classes in the main repository
(`src/main/java/project/NativePhase1.java` and `NativePhase2.java`) and are owned by
this repository. The main repository's Gradle task `verifyJniContract` regenerates
them and fails the build if they differ from these checked-in copies.

Regenerate from the repository that contains both directories:

```powershell
javac -encoding UTF-8 -d build\jni-contract-classes -h LowYSwampHutFinderBase\jni\generated `
  src\main\java\project\NativePhase1.java `
  src\main\java\project\NativePhase2.java
```

Do not hand-edit these files. The JNI function symbols themselves are
`Java_project_*` (package/class names unchanged); only the DLL file name changed
to `LowYSwampHutFinderBase.dll`.
