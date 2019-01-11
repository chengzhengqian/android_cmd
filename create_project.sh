# settings
SDK_DIR=/home/chengzhengqian/Application/android-sdk
VERSION=28.0.0
MAJORVERSION=28
DEVICE="-s 5RE0217B17000565"
# DEVICE="-s 2db4a6b6"
# ISCXXSUPPORT=true 
# use $4
ISCXXSUPPORT=$4
NDKPATH=ndk-toolchain-arm64-api-26
LIBARCH=arm64-v8a
KEYFILE=czq.keystore



proj_dir=`pwd`/$1
mkdir -p $proj_dir
mkdir -p $proj_dir/obj
mkdir -p $proj_dir/bin

src_dir=$proj_dir/src
main_class_path=$2
main_package=$(echo $main_class_path | tr "/" ".")
main_class_dir=$src_dir/$main_class_path
main_class_name=$3
main_class_full_name=$(echo $main_class_path.$main_class_name | tr "/" ".")

mkdir -p $src_dir
mkdir -p $main_class_dir

res_dir=$proj_dir/res
res_layout_dir=$proj_dir/res/layout
res_drawable_dir=$proj_dir/res/drawable
res_values_dir=$proj_dir/res/values
mkdir -p $res_dir
mkdir -p $res_layout_dir
mkdir -p $res_drawable_dir
mkdir -p $res_values_dir

read -r -d '' main_java_file  << EOF
package $main_package;

import android.app.Activity;
import android.os.Bundle;

public class $main_class_name extends Activity{
       @Override
       protected void onCreate(Bundle saved){
              super.onCreate(saved);
       	      setContentView(R.layout.activity_main);
	}
}

EOF


echo "$main_java_file"  > $main_class_dir/$main_class_name.java



read -r -d '' res_strings_xml  << EOF
<resources>
   <string name="app_name">$main_class_name</string>
   <string name="hello_msg">Hello Android from $main_class_name</string>
   <string name="menu_settings">Settings</string>
   <string name="title_activity_main">$main_class_name</string>
</resources>
EOF

echo "$res_strings_xml" > $res_values_dir/strings.xml

read -r -d '' res_layout_main_xml  << EOF
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools"
   android:layout_width="match_parent"
   android:layout_height="match_parent" >
   
   <TextView
      android:layout_width="wrap_content"
      android:layout_height="wrap_content"
      android:layout_centerHorizontal="true"
      android:layout_centerVertical="true"
      android:text="@string/hello_msg"
      tools:context=".$main_class_name" />
</RelativeLayout>
EOF

echo "$res_layout_main_xml" > $res_layout_dir/activity_main.xml

read -r -d '' android_manifest_xml  << EOF
<?xml version='1.0'?>
<manifest xmlns:a='http://schemas.android.com/apk/res/android' package='$main_package' a:versionCode='0' a:versionName='0'>
    <application a:label='$main_class_name'>
        <activity a:name='$main_class_full_name'>
             <intent-filter>
                <category a:name='android.intent.category.LAUNCHER'/>
                <action a:name='android.intent.action.MAIN'/>
             </intent-filter>
        </activity>
    </application>
</manifest>
EOF

echo "$android_manifest_xml" > $proj_dir/AndroidManifest.xml


read -r -d '' makefile  << EOF
proj=$proj_dir
sdk=$SDK_DIR
version=$VERSION
major-version=$MAJORVERSION
aapt=\$(sdk)/build-tools/\$(version)/aapt
dex=\$(sdk)/build-tools/\$(version)/dx
apksigner=\$(sdk)/build-tools/\$(version)/apksigner
zipalign=\$(sdk)/build-tools/\$(version)/zipalign
adb=\$(sdk)/platform-tools/adb
android-jar=\$(sdk)/platforms/android-\$(major-version)/android.jar
include=-I \$(android-jar)
javas=\$(proj)/src/$main_class_path/*.java
src=\$(proj)/src
manifest=\$(proj)/AndroidManifest.xml
res=\$(proj)/res
dex_name=classes.dex
# dex_file=\$(proj)/bin/\$(dex_name)
obj_dir=\$(proj)/obj
apk_name=$main_class_name
apk_file=\$(proj)/bin/\$(apk_name)_unaligned.apk
apk_aligned_file=\$(proj)/bin/\$(apk_name).apk
keyfile=$KEYFILE
device=$DEVICE

# compile resources, -m -J indicates the ouput direction, i.e root of R.java. -M specifies the manifest file, -S specifies the source, -I include the platform jar
R:
	\$(aapt) package -f -m -J \$(src) -M \$(manifest) -S \$(res) \$(include)
	
# compile .java to .class
class: R
	javac -d \$(obj_dir) -classpath \$(src) -bootclasspath \$(android-jar) \$(javas)

dx: class
	\$(dex) --dex --output=\$(dex_name) \$(obj_dir)
	# \$(dex) --dex --output=\$(dex_file) \$(proj_dir)/*.jar \$(obj_dir)
	# to add additional *.jar files

apk: dx
	\$(aapt) package -f -m -F \$(apk_file) -M \$(manifest) -S \$(res) \$(include)
	# cp \$(dex_file) .
	\$(aapt) add \$(apk_file) \$(dex_name)
	# \$(aapt) add \$(apk_file) \$(dex_file) #this will add to the absoulute path

check_apk:
	\$(aapt) list \$(apk_file)

\$(keyfile):
	keytool -genkeypair -validity 365 -keystore \$(keyfile) -keyalg RSA -keysize 2048

key: \$(keyfile)

sign: apk key
	\$(apksigner) sign --ks \$(keyfile) \$(apk_file)

align: apk
	\$(zipalign) -f 4  \$(apk_file) \$(apk_aligned_file)

sign_align: align key
	    \$(apksigner) sign --ks \$(keyfile) \$(apk_aligned_file)
       
install: sign
	\$(adb) \$(device) install -r \$(apk_file)

install_align: sign_align
	\$(adb) \$(device) install -r \$(apk_aligned_file)

run: install
	\$(adb) \$(device) shell am start -n $main_package/.$main_class_name

run_align: install_align
	\$(adb) \$(device) shell am start -n $main_package/.$main_class_name

logcat:
	\$(adb)  \$(device)  logcat 


EOF


echo "$makefile" > $proj_dir/makefile




read -r -d '' makefilecxx  << EOF
#add cxx support

ndk_tool=\$(sdk)/$NDKPATH/
libcxxso=\$(ndk_tool)/aarch64-linux-android/lib/libc++_shared.so
gcc=\$(ndk_tool)/bin/aarch64-linux-android-g++
cc_flags= -fPIC -frtti  -march=armv8-a --sysroot=\$(ndk_tool)/sysroot
# share_lib_dir=./lib/$LIBARCH
share_lib_dir=lib/$LIBARCH
share_lib=\$(share_lib_dir)/libhello.so
copylibcxxso=\$(share_lib_dir)/libc++_shared.so

# general pattern to compile cpp files
\$(proj)/jni/%.o: \$(proj)/jni/%.cpp
	\$(gcc) \$(cc_flags) -c \$< -o \$@

# generate .so 
\$(share_lib): \$(proj)/jni/hello.o
	       mkdir -p \$(share_lib_dir)
	       	\$(gcc) -shared \$< -o \$@

cxxlib:\$(share_lib)

apk_native: cxxlib apk 
	cp \$(libcxxso) \$(copylibcxxso) 
	\$(aapt) add  \$(apk_file) \$(share_lib)
	\$(aapt) add \$(apk_file) \$(copylibcxxso) 

sign_native: apk_native key
	\$(apksigner) sign --ks \$(keyfile) \$(apk_file)

install_native: sign_native
	\$(adb) \$(device) install -r \$(apk_file)

run_native: install_native
	\$(adb) \$(device) shell am start -n $main_package/.$main_class_name



align_native: apk_native
	\$(zipalign) -f 4  \$(apk_file) \$(apk_aligned_file)

sign_align_native: align_native key
	    \$(apksigner) sign --ks \$(keyfile) \$(apk_aligned_file)

install_align_native: sign_align_native
	\$(adb) \$(device) install -r \$(apk_aligned_file)

run_align_native: install_align_native
	\$(adb) \$(device) shell am start -n $main_package/.$main_class_name

EOF

main_package_c=$(echo $main_package | tr "." "_")
read -r -d '' cxxlib  << EOF
#include <string.h>
#include <jni.h>

extern "C" JNIEXPORT jstring Java_${main_package_c}_${main_class_name}_stringFromJNI( JNIEnv* env, jobject thiz ){
  return env->NewStringUTF("hello world form c++!");
}
EOF

read -r -d '' main_java_file  << EOF
package $main_package;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;
import android.view.View;
import android.util.Log;

public class $main_class_name extends Activity{
    @Override
    protected void onCreate(Bundle savedInstanceState){
	super.onCreate(savedInstanceState);
	// setContentView(R.layout.activity_main);
	TextView tv=new TextView(this);
	tv.setText(stringFromJNI()+"\nthis is in java");
	tv.setOnClickListener(new View.OnClickListener(){
		public void onClick(View v){
		    Log.i("$main_package", "clicked");
		}
	    });
	setContentView(tv);	
    }
    public native String  stringFromJNI();

    static {
	Log.i("$main_package", "Trying to load shared library!");
        System.loadLibrary("hello");
    }
}
EOF

jni_dir=$proj_dir/jni


if [  $ISCXXSUPPORT = true ]
   then
       echo "$makefilecxx" >> $proj_dir/makefile
       mkdir -p $jni_dir
       echo "$cxxlib" > $jni_dir/hello.cpp
       echo "$main_java_file"  > $main_class_dir/$main_class_name.java
fi

   
