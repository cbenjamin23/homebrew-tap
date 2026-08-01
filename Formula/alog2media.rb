class Alog2media < Formula
  desc "Render MOOS-IvP alog scenes to MP4, GIF, or PNG without a window"
  homepage "https://github.com/cbenjamin23/alog2media"
  url "https://github.com/cbenjamin23/alog2media/archive/refs/tags/v0.3.1.tar.gz"
  sha256 "dba8ac0eef3034914c124fdda37a687b5d5ee3433894f9f9c6ff33a654377da5"
  license "GPL-3.0-or-later"
  head "https://github.com/cbenjamin23/alog2media.git", branch: "main"

  depends_on "cmake" => :build
  depends_on "ffmpeg"
  depends_on "fltk"
  depends_on "freetype"
  depends_on "libtiff"

  on_linux do
    depends_on "mesa"
  end

  resource "moos-ivp" do
    url "https://github.com/moos-ivp/moos-ivp/archive/174bd7340c33b43e96e1b7eb1ef57aae4df385c9.tar.gz"
    sha256 "488c1075b817024e0412f2c180d3d08fa59b63b0d2666a380d71e46ac88e6b2b"
  end

  def install
    resource("moos-ivp").stage do
      moos_ivp_root = Pathname.pwd
      inreplace "build-moos.sh",
                '"-DPROJ4_LIB_PATH=${PROJ4_LIB_DIR}"',
                '"-DPROJ4_LIB_PATH=${PROJ4_LIB_DIR}" "-DPROJ4_LIBRARY=${PROJ4_LIB_DIR}/libproj.a"'
      system "./build.sh", "-j#{ENV.make_jobs}"

      alog2media_build = buildpath/"brew-build"
      cmake_args = std_cmake_args + %W[
        -DBUILD_TESTING=OFF
        -DCMAKE_INSTALL_LIBDIR=lib/alog2media
        -DMOOS_IVP_ROOT=#{moos_ivp_root}
      ]
      if OS.mac?
        cmake_args << "-DOPENGL_gl_LIBRARY=#{MacOS.sdk_path}/System/Library/Frameworks/OpenGL.framework/OpenGL.tbd"
      end
      system "cmake", "-S", buildpath, "-B", alog2media_build, *cmake_args
      system "cmake", "--build", alog2media_build, "--parallel", ENV.make_jobs
      system "cmake", "--install", alog2media_build
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/alog2media --version")
  end
end
