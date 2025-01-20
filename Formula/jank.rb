class Jank < Formula
  desc "Native Clojure dialect hosted on LLVM"
  homepage "https://jank-lang.org"
  version "0.1"
  license "MPL-2.0"

  stable do
    if OS.linux?
      url "https://github.com/elken/jank/releases/download/latest/jank-linux-x86_64.tar.gz"
    else
      if Hardware::CPU.intel?
        url "https://github.com/elken/jank/releases/download/latest/jank-darwin-x86_64.tar.gz"
      else
        url "https://github.com/elken/jank/releases/download/latest/jank-darwin-arm64.tar.gz"
      end
    end
  end

  head do
    url "https://github.com/jank-lang/jank.git", branch: "main"

    depends_on "cmake" => :build
    depends_on "git-lfs" => :build
    depends_on "ninja" => :build
    depends_on "boost"
  end

  depends_on "bdw-gc"
  depends_on "libzip"
  depends_on "llvm@19"
  depends_on "openssl"

  def install
    if build.head?
      ENV.prepend_path "PATH", Formula["llvm@19"].opt_bin

      ENV.append "LDFLAGS", "-Wl,-rpath,#{Formula["llvm@19"].opt_lib}"

      ENV.append "CPPFLAGS", "-L#{Formula["llvm@19"].opt_include}"

      jank_install_dir = OS.linux? ? libexec : bin
      inreplace "compiler+runtime/cmake/install.cmake",
                '\\$ORIGIN',
                jank_install_dir

      if OS.mac?
        ENV["SDKROOT"] = MacOS.sdk_path
      else
        ENV["CC"] = Formula["llvm@19"].opt_bin/"clang"
        ENV["CXX"] = Formula["llvm@19"].opt_bin/"clang++"
      end

      cd "compiler+runtime"

      system "./bin/configure",
             "-GNinja",
             *std_cmake_args
      system "./bin/compile"
      system "./bin/install"
    else
      prefix.install Dir["#{Dir["*"].first}/local/*"]
    end
  end

  def caveats
    return if OS.mac?
    <<~EOS
      Brew on Linux doesn't setup LD_LIBRARY_PATH correctly, so if you
      get errors about missing shared libraries you should add the
      following to your shell init file.

        export LD_LIBRARY_PATH="/home/linuxbrew/.linuxbrew/lib:$LD_LIBRARY_PATH"

      and restart your shell.
    EOS
  end

  test do
    jank = bin/"jank"

    (testpath/"test.jank").write <<~JANK
      ((fn [] (+ 5 7)))
    JANK

    assert_equal "12", shell_output("#{jank} run test.jank").strip.lines.last

    assert_predicate jank, :exist?, "jank must exist"
    assert_predicate jank, :executable?, "jank must be executable"
  end
end
