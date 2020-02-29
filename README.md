# 手把手教你分离flutter ios 编译产物--附工具


# 1、为什么写这篇文章？

Flutter ios安装包size的裁剪一直是个备受关注的主题，年前字节跳动分享了一篇文章（[https://juejin.im/post/5de8a32c51882512664affa4](https://juejin.im/post/5de8a32c51882512664affa4)），提到了ios分离AOT编译产物，把里面的数据段和资源提取出来以减少安装包size，但文章里面并没有展开介绍如何实现，这篇文章会很详细的分析如何分离AOT编译产物。并给出工具，方便没编译flutter engine经验的同学也可以快速的实现这功能。

# 2、ios编译产物构成

本文主要分析App.framework里面的生成流程，以及如何分离AOT编译产物，App.framework的构成如下图所示。

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/1.png)

主要有App动态库二进制文件、flutter\_assets还有Info.plist三部分构成，而App动态库二进制文件又由4部分构成，vm的数据段、代码段和isolate的数据段、代码段。其中flutter\_assets、vm数据段、isolate数据段都是可以不打包到ipa中，可以从外部document中加载到，这就让我们有缩减ipa包的可能了。

# 3、真实线上项目AOT编译产物前后对比

很多人肯定会关心最终缩减的效果。我们先给出一个真实线上项目，用官方编译engine和用分离产物的engine生成的App.framework的对比图。

官方engine生成的App.framework构成如下，其中App动态库二进制文件19.2M，flutter\_assets有3.3M，共22.5M。

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/2.png)

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/3.png)

用分离产物的engine生成的App.framework构成如下，只剩App动态库二进制文件14.8M。

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/4.png)

App.framework从22.5裁到14.8M，不同项目可能不一样。

# 4、AOT编译产物生成原理及分离方法介绍
每次xcode项目进行进行构建前都会运行xcode\_backend.sh这个脚本进行flutter产物打包，我们从xcode\_backend.sh开始分析。从上文分析App.framework里面总共有三个文件生成二进制文件App、资源文件flutter\_assets目录和Info.plist文件，这里面我们只关心二进制文件App和flutter\_assets目录是怎样生成的。

## 4.1、App文件生成流程

### 4.1.1、xcode\_backend.sh

分析xcode\_backend.sh，我们可以发现生成App和flutter\_assets的关键shell代码如下


```shell

# App动态库二进制文件
RunCommand "${FLUTTER_ROOT}/bin/flutter" --suppress-analytics           \
  ${verbose_flag}                                                       \
  build aot                                                             \
  --output-dir="${build_dir}/aot"                                       \
  --target-platform=ios                                                 \
  --target="${target_path}"                                             \
  --${build_mode}                                                       \
  --ios-arch="${archs}"                                                 \
  ${flutter_engine_flag}                                                \
  ${local_engine_flag}                                                  \
  ${bitcode_flag}

.
.
.

RunCommand cp -r -- "${app_framework}" "${derived_dir}"


# 生成flutter_assets
RunCommand "${FLUTTER_ROOT}/bin/flutter"     \
    ${verbose_flag}                                                         \
    build bundle                                                            \
    --target-platform=ios                                                   \
    --target="${target_path}"                                               \
    --${build_mode}                                                         \
    --depfile="${build_dir}/snapshot_blob.bin.d"                            \
    --asset-dir="${derived_dir}/App.framework/${assets_path}"               \
    ${precompilation_flag}                                                  \
    ${flutter_engine_flag}                                                  \
    ${local_engine_flag}                                                    \
    ${track_widget_creation_flag}
```

### 4.1.2、${FLUTTER_ROOT}/bin/flutter

从上面的代码可以看到这里调用了的远行了 **${FLUTTER_ROOT}/bin/flutter** 这个shell脚本，这里介绍另一篇[讲解Flutter命令执行机制的文章](http://gityuan.com/2019/09/01/flutter_tool/)， **${FLUTTER_ROOT}/bin/flutter** 里面提到真正运行代码的是

```shell
...
FLUTTER_TOOLS_DIR="$FLUTTER_ROOT/packages/flutter_tools"
SNAPSHOT_PATH="$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot"
STAMP_PATH="$FLUTTER_ROOT/bin/cache/flutter_tools.stamp"
SCRIPT_PATH="$FLUTTER_TOOLS_DIR/bin/flutter_tools.dart"
DART_SDK_PATH="$FLUTTER_ROOT/bin/cache/dart-sdk"

DART="$DART_SDK_PATH/bin/dart"
PUB="$DART_SDK_PATH/bin/pub"

//真正的执行逻辑
"$DART" $FLUTTER_TOOL_ARGS "$SNAPSHOT_PATH" "$@"

//等价于下面的命令
/bin/cache/dart-sdk/bin/dart $FLUTTER_TOOL_ARGS "bin/cache/flutter_tools.snapshot" "$@"

```

就是说通过dart命令运行flutter_tools.snapshot这个产物


###4.1.3、dart代码

flutter\_tools.snapshot的入口是

**\[-> flutter/packages/flutter\_tools/bin/flutter_tools.dart]**

```
import 'package:flutter_tools/executable.dart' as executable;

void main(List<String> args) {
  executable.main(args); 
}

```

```
import 'runner.dart' as runner;

Future<void> main(List<String> args) async {
  ...
  await runner.run(args, <FlutterCommand>[
    AnalyzeCommand(verboseHelp: verboseHelp),
    AttachCommand(verboseHelp: verboseHelp),
    BuildCommand(verboseHelp: verboseHelp),
    ChannelCommand(verboseHelp: verboseHelp),
    CleanCommand(),
    ConfigCommand(verboseHelp: verboseHelp),
    CreateCommand(),
    DaemonCommand(hidden: !verboseHelp),
    DevicesCommand(),
    DoctorCommand(verbose: verbose),
    DriveCommand(),
    EmulatorsCommand(),
    FormatCommand(),
    GenerateCommand(),
    IdeConfigCommand(hidden: !verboseHelp),
    InjectPluginsCommand(hidden: !verboseHelp),
    InstallCommand(),
    LogsCommand(),
    MakeHostAppEditableCommand(),
    PackagesCommand(),
    PrecacheCommand(),
    RunCommand(verboseHelp: verboseHelp),
    ScreenshotCommand(),
    ShellCompletionCommand(),
    StopCommand(),
    TestCommand(verboseHelp: verboseHelp),
    TraceCommand(),
    TrainingCommand(),
    UpdatePackagesCommand(hidden: !verboseHelp),
    UpgradeCommand(),
    VersionCommand(),
  ], verbose: verbose,
     muteCommandLogging: muteCommandLogging,
     verboseHelp: verboseHelp,
     overrides: <Type, Generator>{
       CodeGenerator: () => const BuildRunner(),
     });
}

```

经过一轮调用后，真正编译产物的类在 GenSnapshot.run,调用栈[http://gityuan.com/2019/09/07/flutter_run/](http://gityuan.com/2019/09/07/flutter_run/)这篇文章有详细介绍，这里就不细说了

**[-> lib/src/base/build.dart]**

```
class GenSnapshot {

  Future<int> run({
    @required SnapshotType snapshotType,
    IOSArch iosArch,
    Iterable<String> additionalArgs = const <String>[],
  }) {
    final List<String> args = <String>[
      '--causal_async_stacks',
    ]..addAll(additionalArgs);
    //获取gen_snapshot命令的路径
    final String snapshotterPath = getSnapshotterPath(snapshotType);

    //iOS gen_snapshot是一个多体系结构二进制文件。 作为i386二进制文件运行将生成armv7代码。 作为x86_64二进制文件运行将生成arm64代码。
    // /usr/bin/arch可用于运行具有指定体系结构的二进制文件
    if (snapshotType.platform == TargetPlatform.ios) {
      final String hostArch = iosArch == IOSArch.armv7 ? '-i386' : '-x86_64';
      return runCommandAndStreamOutput(<String>['/usr/bin/arch', hostArch, snapshotterPath]..addAll(args));
    }
    return runCommandAndStreamOutput(<String>[snapshotterPath]..addAll(args));
  }
}

```

GenSnapshot.run具体命令根据前面的封装，最终等价于：

```
//这是针对iOS的genSnapshot命令
/usr/bin/arch -x86_64 flutter/bin/cache/artifacts/engine/ios-release/gen_snapshot
  --causal_async_stacks
  --deterministic
  --snapshot_kind=app-aot-assembly
  --assembly=build/aot/arm64/snapshot_assembly.S
  build/aot/app.dill

```

此处gen\_snapshot是一个二进制可执行文件，所对应的执行方法源码为third\_party/dart/runtime/bin/gen\_snapshot.cc
这个文件是flutter engine里面文件，需要拉取engine的代码才能修改，编译flutter engine 可以参考文章[手把手教你编译Flutter engine](https://juejin.im/post/5c24acd5f265da6164141236)，下文我们也会介绍编译完flutter engine ，怎么拿到gen_snapshot编译后的二进制文件。

###4.1.4、flutter engine c++代码
[Flutter机器码生成gen\_snapshot](http://gityuan.com/2019/09/21/flutter_gen_snapshot/)这篇文章对gen\_snapshot流程做了详细的分析，这里我直接给出最后结论，生成数据段和代码段的代码在
**AssemblyImageWriter::WriteText**这个函数里面

**\[-> third\_party/dart/runtime/vm/image\_snapshot.cc]**


```cpp

void AssemblyImageWriter::WriteText(WriteStream* clustered_stream, bool vm) {
  Zone* zone = Thread::Current()->zone();
  //写入头部
  const char* instructions_symbol = vm ? "_kDartVmSnapshotInstructions" : "_kDartIsolateSnapshotInstructions";
  assembly_stream_.Print(".text\n");
  assembly_stream_.Print(".globl %s\n", instructions_symbol);
  assembly_stream_.Print(".balign %" Pd ", 0\n", VirtualMemory::PageSize());
  assembly_stream_.Print("%s:\n", instructions_symbol);

  //写入头部空白字符，使得指令快照看起来像堆页
  intptr_t instructions_length = next_text_offset_;
  WriteWordLiteralText(instructions_length);
  intptr_t header_words = Image::kHeaderSize / sizeof(uword);
  for (intptr_t i = 1; i < header_words; i++) {
    WriteWordLiteralText(0);
  }

  //写入序幕.cfi_xxx
  FrameUnwindPrologue();

  Object& owner = Object::Handle(zone);
  String& str = String::Handle(zone);
  ObjectStore* object_store = Isolate::Current()->object_store();

  TypeTestingStubNamer tts;
  intptr_t text_offset = 0;

  for (intptr_t i = 0; i < instructions_.length(); i++) {
    auto& data = instructions_[i];
    const bool is_trampoline = data.trampoline_bytes != nullptr;
    if (is_trampoline) {     //针对跳床函数
      const auto start = reinterpret_cast<uword>(data.trampoline_bytes);
      const auto end = start + data.trampline_length;
       //写入.quad xxx字符串
      text_offset += WriteByteSequence(start, end);
      delete[] data.trampoline_bytes;
      data.trampoline_bytes = nullptr;
      continue;
    }

    const intptr_t instr_start = text_offset;
    const Instructions& insns = *data.insns_;
    const Code& code = *data.code_;
    // 1. 写入 头部到入口点
    {
      NoSafepointScope no_safepoint;

      uword beginning = reinterpret_cast<uword>(insns.raw_ptr());
      uword entry = beginning + Instructions::HeaderSize(); //ARM64 32位对齐

      //指令的只读标记
      uword marked_tags = insns.raw_ptr()->tags_;
      marked_tags = RawObject::OldBit::update(true, marked_tags);
      marked_tags = RawObject::OldAndNotMarkedBit::update(false, marked_tags);
      marked_tags = RawObject::OldAndNotRememberedBit::update(true, marked_tags);
      marked_tags = RawObject::NewBit::update(false, marked_tags);
      //写入标记
      WriteWordLiteralText(marked_tags);
      beginning += sizeof(uword);
      text_offset += sizeof(uword);
      text_offset += WriteByteSequence(beginning, entry);
    }

    // 2. 在入口点写入标签
    owner = code.owner();
    if (owner.IsNull()) {  
      // owner为空，说明是一个常规的stub，其中stub列表定义在stub_code_list.h中的VM_STUB_CODE_LIST
      const char* name = StubCode::NameOfStub(insns.EntryPoint());
      if (name != nullptr) {
        assembly_stream_.Print("Precompiled_Stub_%s:\n", name);
      } else {
        if (name == nullptr) {
          // isolate专有的stub代码[见小节3.5.1]
          name = NameOfStubIsolateSpecificStub(object_store, code);
        }
        assembly_stream_.Print("Precompiled__%s:\n", name);
      }
    } else if (owner.IsClass()) {
      //owner为Class，说明是该类分配的stub，其中class列表定义在class_id.h中的CLASS_LIST_NO_OBJECT_NOR_STRING_NOR_ARRAY
      str = Class::Cast(owner).Name();
      const char* name = str.ToCString();
      EnsureAssemblerIdentifier(const_cast<char*>(name));
      assembly_stream_.Print("Precompiled_AllocationStub_%s_%" Pd ":\n", name,
                             i);
    } else if (owner.IsAbstractType()) {
      const char* name = tts.StubNameForType(AbstractType::Cast(owner));
      assembly_stream_.Print("Precompiled_%s:\n", name);
    } else if (owner.IsFunction()) { //owner为Function，说明是一个常规的dart函数
      const char* name = Function::Cast(owner).ToQualifiedCString();
      EnsureAssemblerIdentifier(const_cast<char*>(name));
      assembly_stream_.Print("Precompiled_%s_%" Pd ":\n", name, i);
    } else {
      UNREACHABLE();
    }

#ifdef DART_PRECOMPILER
    // 创建一个标签用于DWARF
    if (!code.IsNull()) {
      const intptr_t dwarf_index = dwarf_->AddCode(code);
      assembly_stream_.Print(".Lcode%" Pd ":\n", dwarf_index);
    }
#endif

    {
      // 3. 写入 入口点到结束
      NoSafepointScope no_safepoint;
      uword beginning = reinterpret_cast<uword>(insns.raw_ptr());
      uword entry = beginning + Instructions::HeaderSize();
      uword payload_size = insns.raw()->HeapSize() - insns.HeaderSize();
      uword end = entry + payload_size;
      text_offset += WriteByteSequence(entry, end);
    }
  }

  FrameUnwindEpilogue();

#if defined(TARGET_OS_LINUX) || defined(TARGET_OS_ANDROID) ||                  \
    defined(TARGET_OS_FUCHSIA)
  assembly_stream_.Print(".section .rodata\n");
#elif defined(TARGET_OS_MACOS) || defined(TARGET_OS_MACOS_IOS)
  assembly_stream_.Print(".const\n");
#else
  UNIMPLEMENTED();
#endif
  //写入数据段
  const char* data_symbol = vm ? "_kDartVmSnapshotData" : "_kDartIsolateSnapshotData";
  assembly_stream_.Print(".globl %s\n", data_symbol);
  assembly_stream_.Print(".balign %" Pd ", 0\n",
                         OS::kMaxPreferredCodeAlignment);
  assembly_stream_.Print("%s:\n", data_symbol);
  uword buffer = reinterpret_cast<uword>(clustered_stream->buffer());
  intptr_t length = clustered_stream->bytes_written();
  WriteByteSequence(buffer, buffer + length);
}

```

这里是生成的是snapshot\_assembly.S，后面在dart代码还将对这个文件加工成App动态库文件，我们会在下文介绍，**我们要做代码段和数据段分离修改的就是这个c++函数**，首先改掉代码不写进snapshot_assembly.S，在另外的地方把二进制数据保存起来。后面通过修改engine的加载流程从外部加载这二进制数据，即可达到分离代码段和数据段的目的。下面我们继续分析生成完snapshot\_assembly.S后，在哪里生成App动态库二进制文件。

### 4.1.5、dart代码调用xcrun生成二进制文件和动态库

生成完snapshot\_assembly.S后，再加工关键代码在**[-> lib/src/base/build.dart]**

```
 /// Builds an iOS or macOS framework at [outputPath]/App.framework from the assembly
  /// source at [assemblyPath].
  Future<RunResult> _buildFramework({
    @required DarwinArch appleArch,
    @required bool isIOS,
    @required String assemblyPath,
    @required String outputPath,
    @required bool bitcode,
    @required bool quiet
  }) async {
    final String targetArch = getNameForDarwinArch(appleArch);
    if (!quiet) {
      printStatus('Building App.framework for $targetArch...');
    }

    final List<String> commonBuildOptions = <String>[
      '-arch', targetArch,
      if (isIOS)
        '-miphoneos-version-min=8.0',
    ];

    const String embedBitcodeArg = '-fembed-bitcode';
    final String assemblyO = fs.path.join(outputPath, 'snapshot_assembly.o');
    List<String> isysrootArgs;
    if (isIOS) {
      final String iPhoneSDKLocation = await xcode.sdkLocation(SdkType.iPhone);
      if (iPhoneSDKLocation != null) {
        isysrootArgs = <String>['-isysroot', iPhoneSDKLocation];
      }
    }
    //生成snapshot_assembly.o二进制文件
    final RunResult compileResult = await xcode.cc(<String>[
      '-arch', targetArch,
      if (isysrootArgs != null) ...isysrootArgs,
      if (bitcode) embedBitcodeArg,
      '-c',
      assemblyPath,
      '-o',
      assemblyO,
    ]);
    if (compileResult.exitCode != 0) {
      printError('Failed to compile AOT snapshot. Compiler terminated with exit code ${compileResult.exitCode}');
      return compileResult;
    }

    final String frameworkDir = fs.path.join(outputPath, 'App.framework');
    fs.directory(frameworkDir).createSync(recursive: true);
    final String appLib = fs.path.join(frameworkDir, 'App');
    final List<String> linkArgs = <String>[
      ...commonBuildOptions,
      '-dynamiclib',
      '-Xlinker', '-rpath', '-Xlinker', '@executable_path/Frameworks',
      '-Xlinker', '-rpath', '-Xlinker', '@loader_path/Frameworks',
      '-install_name', '@rpath/App.framework/App',
      if (bitcode) embedBitcodeArg,
      if (isysrootArgs != null) ...isysrootArgs,
      '-o', appLib,
      assemblyO,
    ];
    //打包成动态库
    final RunResult linkResult = await xcode.clang(linkArgs);
    if (linkResult.exitCode != 0) {
      printError('Failed to link AOT snapshot. Linker terminated with exit code ${compileResult.exitCode}');
    }
    return linkResult;
  }

```

这里最终会调用xcrun cc命令和xcrun clang命令打包动态库二进制文件。

### 4.1.6、修改生成动态库文件App的流程

根据上面的分析整个流程涉及dart代码和c++代码，dart代码其实不在engine，属于flutter项目，只需要用打开**[-> packages/flutter_tools]**这个flutter
项目，直接修改就好，要注意一点，flutter\_tools的编译产物是有缓存的，缓存路径是**[-> bin/cache/flutter\_tools.snapshot]**，每次我们修改完dart代码，都需要删掉flutter\_tools.snapshot重新生成才能生效。

那c++部分代码呢，首先设计c++代码都是需要重新编译flutter engine， 可以参考文章[手把手教你编译Flutter engine](https://juejin.im/post/5c24acd5f265da6164141236)，编译后engine的产物，如下图

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/5.png)

把编译后的gen\_snapshot文件拷贝到flutter目录下，下图的位置即可。

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/6.png)

注意，engine是分架构的，arm64的gen_snapshot名字是gen\_snapshot\_arm64，armv7的gen\_snapshot名字是gen\_snapshot\_armv7，完成替换后，我们定制的代码就可以生效了。

### 4.1.7、生成动态库文件App流程总结

至此，生成动态库文件App的全部流程都介绍清楚了，关键部分就是修改4.1.4提到的c++函数，我们修改完后的编译产物如下。

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/7.png)

提取到了4个文件，分别是arm64和armv7架构下的vm数据段和isolate数据段，可以按需下发给数据段文件给应用，从而实现flutter ios 动态库编译产物的裁剪。

## 4.2、flutter\_assets生成流程

像4.1.1和4.1.2说的那样，具体生成flutter\_assets的代码在BundleBuilder.dart文件

**[-> packages/flutter\_tools/lib/src/bundle.dart]**

```
Future<void> build({
    @required TargetPlatform platform,
    BuildMode buildMode,
    String mainPath,
    String manifestPath = defaultManifestPath,
    String applicationKernelFilePath,
    String depfilePath,
    String privateKeyPath = defaultPrivateKeyPath,
    String assetDirPath,
    String packagesPath,
    bool precompiledSnapshot = false,
    bool reportLicensedPackages = false,
    bool trackWidgetCreation = false,
    List<String> extraFrontEndOptions = const <String>[],
    List<String> extraGenSnapshotOptions = const <String>[],
    List<String> fileSystemRoots,
    String fileSystemScheme,
  }) async {
    mainPath ??= defaultMainPath;
    depfilePath ??= defaultDepfilePath;
    assetDirPath ??= getAssetBuildDirectory();
    printStatus("assetDirPath" + assetDirPath);
    printStatus("mainPath" + mainPath);
    packagesPath ??= fs.path.absolute(PackageMap.globalPackagesPath);
    final FlutterProject flutterProject = FlutterProject.current();
    await buildWithAssemble(
      buildMode: buildMode ?? BuildMode.debug,
      targetPlatform: platform,
      mainPath: mainPath,
      flutterProject: flutterProject,
      outputDir: assetDirPath,
      depfilePath: depfilePath,
      precompiled: precompiledSnapshot,
      trackWidgetCreation: trackWidgetCreation,
    );
    // Work around for flutter_tester placing kernel artifacts in odd places.
    if (applicationKernelFilePath != null) {
      final File outputDill = fs.directory(assetDirPath).childFile('kernel_blob.bin');
      if (outputDill.existsSync()) {
        outputDill.copySync(applicationKernelFilePath);
      }
    }
    return;
  }

```

这里assetDirPath就是最终打包产生bundle产物的路径，我们只要修改这个路径，不指向App.framework，指向其他路径，就可以避免打包进app。

## 4.3、AOT编译产物生成原理总结

至此，我们已经把AOT编译产物里面的动态库文件App、flutter\_assets，的生成流程解析清楚了，也把如何分离的方法介绍了，对我们的demo做完修改后的产物跟分离前的产物对比如下图所示

分离前

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/8.png)

分离后

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/9.png)

那下面我们分析如何修改flutter engine的加载流程，使engine不再加载App.framework里面的资源（因为已经分离出来），去加载外部给予的资源

# 5、AOT编译产物加载流程及修改方法介绍

上面我们已经成功从App.framework里面分离出了数据段数据已经flutter\_assets，现在需要修改加载流程，加载外部数据。

## 5.1、数据段加载流程分析及修改

加载数据段的堆栈如下。

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/10.png)

可以看到其实是用::dlsym从动态库里面读出数据段的数据强转成const uint8_t*使用，我们只要修改代码，不从动态库读取，外部提供一个const uint8_t*来代替就好了

我最终选择在下图的两个地方修改

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/11.png)

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/12.png)

这里我直接构造一个SymbolMapping返回，SymbolMapping的定义如下

```cpp

class SymbolMapping final : public Mapping {
 public:
  SymbolMapping(fml::RefPtr<fml::NativeLibrary> native_library,
                const char* symbol_name);
                
  //新增一个构造函数直接传如外部数据
  SymbolMapping(const uint8_t * data);

  ~SymbolMapping() override;

  // |Mapping|
  size_t GetSize() const override;

  // |Mapping|
  const uint8_t* GetMapping() const override;

 private:
  fml::RefPtr<fml::NativeLibrary> native_library_;
  const uint8_t* mapping_ = nullptr;

  FML_DISALLOW_COPY_AND_ASSIGN(SymbolMapping);
};

```

修改了这里，我们就可以完成外部数据段的加载了。

## 5.2、flutter\_assets加载流程分析及修改

这个比较简单，我们直接上代码，

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/13.png)

只要改了settings.assets\_path，改成外部的路径就好了。

## 5.3、修改engine总结

到这里，我们已经成功分离好engine了，分离之后对于很多混编的项目就是，flutter并不是必须的，就可以吧数据段部分和flutter\_assets不打包进ipa，按需的下载下来，从而实现ipa的减size，下午会给出编好的engine、gen\_snapshot文件和demo。当然，有些业务甚至不希望下载，想调用流程完全不变，也可以减size，这个由于篇幅有限，我们后面再写一篇专门给出方法和工具。

# 6、工具介绍和使用

从上面的分析可以看出，搞这个事情，要很多铺垫，很麻烦，很多同学并不想摸索这么久才能在自己的项目进行实验，看效果，为了方便大家验证，我直接把基于v1.12.13+hotfix.7编好的engine、gen\_snapshot文件和demo放到[github](https://github.com/williamwen1986/flutter_slim)上，让大家直接用.编出来的Flutter.framework是全架构支持的、经过优化的release版，可以直接上线的。下面介绍下运行流程。

## 6.1如何运行demo验证

在[github](https://github.com/williamwen1986/flutter_slim)上下载demo，不做任何改动，用真机直接运行，可以看到产物如下图所示，App动态库 5.5M，flutter\_assets 715k，总大小 6.3M。

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/14.png)

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/15.png)

然后执行下面的操作，替换engine

* 把github上的Flutter.framework覆盖掉[->/bin/cache/artifacts/engine/ios-release/Flutter.framework]这个目下的Flutter.framework

* 把github上的gen\_snapshot\_arm64覆盖掉[->/bin/cache/artifacts/engine/ios-release/gen\_snapshot\_arm64]

* 把github上的gen\_snapshot\_armv7覆盖掉[->/bin/cache/artifacts/engine/ios-release/gen\_snapshot\_armv7]

* 然后把github上的bundle.dart覆盖掉[->packages/flutter\_tools/lib/src/bundle.dart]目录下的bundle.dart文件

* 然后删掉[->bin/cache/flutter\_tools.snapshot],这个文件是dart项目生成的二进制文件，删除了新的bundle.dart才能生效

* 然后重新跑起项目，观察编译产物


可以看到产物如下图所示，只剩下4.6M的产物了，这是demo的压缩效果。

![image](https://raw.githubusercontent.com/williamwen1986/flutter_slim/master/img/16.png)

# 7、总结

目前使用这方案，可以分离编译产物和flutter\_assets，但也需要app做一定的改动，就是从服务器下载数据段和flutter\_assets，才能运行flutter。当然还有一个方法，直接对数据段进行压缩，运行的时候解压，这个也是可行的，但压缩率就没这么高，后面我们也会开源并给出文章介绍。