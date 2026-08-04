class Alog2media < Formula
  desc "Render MOOS-IvP alog scenes to MP4, GIF, or PNG without a window"
  homepage "https://github.com/cbenjamin23/alog2media"
  url "https://github.com/cbenjamin23/alog2media/archive/refs/tags/v0.3.3.tar.gz"
  sha256 "469c6c37e2a42937d2e4b43e49064fb42f9f0e83104b305db93c2fa19358ceb3"
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
        linux_opengl_find = [
          "find_package(OpenGL REQUIRED)",
          "find_path(EGL_INCLUDE_DIR NAMES EGL/egl.h REQUIRED)",
          "find_library(EGL_LIBRARY NAMES EGL REQUIRED)",
        ].join("\n")
        inreplace buildpath/"CMakeLists.txt",
                  "find_package(OpenGL REQUIRED COMPONENTS OpenGL EGL)",
                  linux_opengl_find
        inreplace buildpath/"CMakeLists.txt",
                  "OpenGL::OpenGL OpenGL::EGL",
                  'OpenGL::GL "${EGL_LIBRARY}"'
        cmake_args += %W[
          -DOpenGL_GL_PREFERENCE=LEGACY
          -DOPENGL_INCLUDE_DIR=#{mesa.opt_include}
          -DOPENGL_gl_LIBRARY=#{mesa.opt_lib}/libGL.so
          -DEGL_INCLUDE_DIR=#{mesa.opt_include}
          -DEGL_LIBRARY=#{mesa.opt_lib}/libEGL.so
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
      0.00001 REGION_INFO pMarineViewer lat_datum=42,lon_datum=-71,img_file=forrest19.tif,zoom=1,pan_x=0,pan_y=0
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
    assert_path_exists pkgshare/"maps/forrest19.tif"
    assert_path_exists pkgshare/"maps/forrest19.info"
    system bin/"alog2media", testpath/"smoke.alog", "--at", "0.5",
           "--view", "fit", "--size", "64x64",
           "--output", testpath/"smoke.png"
    assert_path_exists testpath/"smoke.png"
  end
end
