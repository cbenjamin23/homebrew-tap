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
      elsif OS.linux?
        mesa = Formula["mesa"]
        cmake_args += %W[
          -DOPENGL_INCLUDE_DIR=#{mesa.opt_include}
          -DOPENGL_EGL_INCLUDE_DIR=#{mesa.opt_include}
          -DOPENGL_opengl_LIBRARY=#{mesa.opt_lib}/libOpenGL.so
          -DOPENGL_egl_LIBRARY=#{mesa.opt_lib}/libEGL.so
        ]
      end
      system "cmake", "-S", buildpath, "-B", alog2media_build, *cmake_args
      system "cmake", "--build", alog2media_build, "--parallel", ENV.make_jobs
      system "cmake", "--install", alog2media_build
    end
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/alog2media --version")

    (testpath/"smoke.alog").write <<~ALOG
      %%%% LOGSTART 1000.0
      0.00000 DB_TIME MOOSDB 1000.0
      0.00001 REGION_INFO pMarineViewer lat_datum=42,lon_datum=-71,zoom=1,pan_x=0,pan_y=0
      0.00002 NODE_REPORT_LOCAL pNodeReporter NAME=alpha,TYPE=kayak,COLOR=yellow,LENGTH=4
      0.00003 NAV_X uSimMarine -10
      0.00004 NAV_Y uSimMarine -5
      0.00005 NAV_HEADING uSimMarine 90
      0.50000 VIEW_POINT pMarineViewer x=0,y=0,label=ORIGIN,vertex_color=red
      1.00003 NAV_X uSimMarine 10
      1.00004 NAV_Y uSimMarine 5
      1.00005 NAV_HEADING uSimMarine 45
    ALOG
    if OS.linux?
      ENV["EGL_PLATFORM"] = "surfaceless"
      ENV["LIBGL_ALWAYS_SOFTWARE"] = "1"
    end
    system bin/"alog2media", testpath/"smoke.alog", "--map", "none",
           "--at", "0.5", "--view", "fit", "--size", "64x64",
           "--output", testpath/"smoke.png"
    assert_path_exists testpath/"smoke.png"
  end
end
