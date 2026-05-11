#!/bin/bash
# ========================================================
# Raditz Build Script V1.7 - Cisfan Edition
# Proyecto: BQ Aquaris V Plus (MSM8940)
# ========================================================

# --- 1. RUTAS DEL PROYECTO ---
CR_DIR=$(pwd)
CR_STUFF=$CR_DIR/cisfan-stuff
CR_AIK=$CR_STUFF/A.I.K
CR_OUT=$CR_STUFF/out
CR_K_OUT=$CR_STUFF/kernel-out

# --- 2. TOOLCHAIN (Tu ruta absoluta) ---
CR_TC=/home/izan/Documentos/kernel-raditz-definitive/aarch64-linux-android-4.9-master/bin/aarch64-linux-android-

# --- 3. CONFIGURACIÓN DE CCACHE ---
if [ -x "$(command -v ccache)" ]; then
    export USE_CCACHE=1
    export CCACHE_EXEC=$(command -v ccache)
    CROSS_COMPILE_PREFIX="$CCACHE_EXEC $CR_TC"
else
    CROSS_COMPILE_PREFIX="$CR_TC"
fi

# --- 4. EXPORTAR VARIABLES Y PARCHES ---
export ARCH=arm64
export CROSS_COMPILE="$CROSS_COMPILE_PREFIX"
export KCFLAGS="-fcommon -Wno-error"
export HOSTCFLAGS="-fcommon"
export HOSTLDFLAGS="-fcommon"

# Datos del Kernel
CR_CONFG=raditz_defconfig 
CR_DTS_PATH=$CR_K_OUT/arch/arm64/boot/dts/qcom
CR_DTB_NAME=raditz.dtb 
CR_VERSION=V1.0
export KBUILD_BUILD_USER="Cisfan"
export KBUILD_BUILD_HOST="Raditz-Dev"

# --- INICIO DEL SCRIPT ---
mkdir -p $CR_OUT $CR_K_OUT
clear
echo "--------------------------------------------------------"
echo "   COMPILADOR KERNEL RADITZ - CISFAN EDITION"
echo "--------------------------------------------------------"

# 1. Menú de Limpieza
read -p "Quieres hacer una limpieza profunda (clean/mrproper)? (y/n) > " yn
if [ "$yn" = "y" -o "$yn" = "Y" ]; then
    echo "--- [CLEAN] Limpiando todo... ---"
    make mrproper
    rm -rf $CR_K_OUT/*
    if [ -d "$CR_AIK" ]; then cd $CR_AIK && ./cleanup.sh && cd $CR_DIR; fi
fi

# 2. Parche Crítico yylloc (Para evitar el error de compilación)
echo "--- [PATCH] Aplicando parche yylloc en scripts/dtc ---"
if [ -f "scripts/dtc/dtc-lexer.lex.c_shipped" ]; then
    sed -i 's/^YYLTYPE yylloc;/extern YYLTYPE yylloc;/g' scripts/dtc/dtc-lexer.lex.c_shipped
fi

# 3. Configurar defconfig y firma
echo "--- [KERNEL] Configurando $CR_CONFG ---"
make O=$CR_K_OUT $CR_CONFG
sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-Cisfan-'$CR_VERSION'"/g' $CR_K_OUT/.config

# 4. Compilación Principal
echo "--- [KERNEL] Compilando... Esto tardará según tu PC ---"
make O=$CR_K_OUT -j$(nproc --all)
make O=$CR_K_OUT dtbs

# 5. Verificación y Empaquetado
if [ -f "$CR_K_OUT/arch/arm64/boot/Image.gz" ]; then
    echo "--- [EXITO] Kernel compilado. ---"
    
    # Unir Kernel + DTB
    echo "--- [DTB] Uniendo DTB al kernel... ---"
    cat $CR_K_OUT/arch/arm64/boot/Image.gz $CR_DTS_PATH/$CR_DTB_NAME > $CR_DIR/Image.gz-dtb
    
    # Empaquetar con AIK
    if [ -d "$CR_AIK/split_img" ]; then
        echo "--- [AIK] Reempaquetando boot.img... ---"
        cp $CR_DIR/Image.gz-dtb $CR_AIK/split_img/boot.img-zImage
        cd $CR_AIK
        ./repackimg.sh
        mv image-new.img $CR_OUT/boot-Cisfan-Raditz-$CR_VERSION.img
        cd $CR_DIR
        echo "--------------------------------------------------------"
        echo "  ¡PROCESO FINALIZADO!"
        echo "  Imagen lista en: $CR_OUT"
        echo "--------------------------------------------------------"
    else
        echo "--- [ERROR] No existe la carpeta split_img en AIK. ---"
        echo "--- Haz el unpack del boot original primero. ---"
        exit 1
    fi
else
    echo "--- [ERROR] La compilación falló. Revisa los errores arriba. ---"
    exit 1
fi

