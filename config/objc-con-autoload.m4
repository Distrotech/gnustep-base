AC_DEFUN(OBJC_CON_AUTOLOAD,
#--------------------------------------------------------------------
# Guess if we are using a object file format that supports automatic
# loading of constructor functions.
#
# If this system supports autoloading of constructors, that means that gcc
# doesn't have to do it for us via collect2. This routine tests for this
# in a very roundabout way by compiling a program with a constructor and
# testing the file, via nm, for certain symbols that collect2 includes to
# handle loading of constructors.
#
# Makes the following substitutions:
#	Defines CON_AUTOLOAD (whether constructor functions are autoloaded)
#--------------------------------------------------------------------
[dnl
AC_MSG_CHECKING(loading of constructor functions)
AC_CACHE_VAL(objc_cv_con_autoload,
[dnl 
cat > conftest.constructor.c <<EOF
void cons_functions() __attribute__ ((constructor));
void cons_functions() {}
int main()
{
  return 0;
}
EOF
${CC-cc} -o conftest${ac_exeext} $CFLAGS $CPPFLAGS $LDFLAGS conftest.constructor.$ac_ext $LIBS 1>&5
case "$target_os" in
    cygwin*)	objc_cv_con_autoload=yes;;
    *)	if test -n "`nm conftest${ac_exeext} | grep global_ctors`"; then 
  	  objc_cv_con_autoload=yes
	else
  	  objc_cv_con_autoload=no 
	fi ;;
esac
])
if test $objc_cv_con_autoload = yes; then
  AC_MSG_RESULT(yes)
  AC_DEFINE(CON_AUTOLOAD,,[Define if constructors are automatically loaded])
else
  AC_MSG_RESULT(no)
fi
])
