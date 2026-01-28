*&---------------------------------------------------------------------*
*& Report ZMM_INVENTORY_REPORT
*&---------------------------------------------------------------------*
*&
*& 程序名称  : 物料库存查询报表
*& 功能描述  : 查询物料在各工厂/库存地点的可用库存
*& 创建者    : Developer
*& 创建日期  : 2024.01.28
*&---------------------------------------------------------------------*
REPORT zmm_inventory_report.

*----------------------------------------------------------------------*
* INCLUDE 程序定义
*----------------------------------------------------------------------*
INCLUDE: zmm_inventory_reporttop,  " 全局数据定义
         zmm_inventory_reportsel,  " 选择屏幕
         zmm_inventory_reportf01,  " 子程序
         zmm_inventory_reporto01,  " PBO模块
         zmm_inventory_reporti01.  " PAI模块

*----------------------------------------------------------------------*
* 选择屏幕事件
*----------------------------------------------------------------------*
START-OF-SELECTION.
  PERFORM data_validation.    " 数据验证
  PERFORM get_inventory_data. " 获取库存数据
  PERFORM process_data.       " 处理数据
  PERFORM display_results.    " 显示结果

END-OF-SELECTION.


*全局数据定义 (ZMM_INVENTORY_REPORTTOP)
*&---------------------------------------------------------------------*
*& Include          ZMM_INVENTORY_REPORTTOP
*&---------------------------------------------------------------------*

* 表定义
TABLES: mara,  " 物料主数据
        makt,  " 物料描述
        mbew,  " 物料评估
        mard,  " 库存地点数据
        t001w, " 工厂
        t001l. " 库存地点

* 类型定义
TYPES: BEGIN OF ty_material_info,
         matnr TYPE mara-matnr,      " 物料号
         maktx TYPE makt-maktx,      " 物料描述
         werks TYPE mard-werks,      " 工厂
         lgort TYPE mard-lgort,      " 库存地点
         labst TYPE mard-labst,      " 非限制库存
         umlme TYPE mard-umlme,      " 在途库存
         insme TYPE mard-insme,      " 质检库存
         speme TYPE mard-speme,      " 冻结库存
         total TYPE mard-labst,      " 总可用库存
         meins TYPE mara-meins,      " 基本计量单位
       END OF ty_material_info.

TYPES: BEGIN OF ty_output,
         matnr     TYPE mara-matnr,
         maktx     TYPE makt-maktx,
         werks     TYPE mard-werks,
         werks_txt TYPE t001w-name1,
         lgort     TYPE mard-lgort,
         lgort_txt TYPE t001l-lgobe,
         labst     TYPE mard-labst,
         umlme     TYPE mard-umlme,
         insme     TYPE mard-insme,
         speme     TYPE mard-speme,
         total     TYPE mard-labst,
         meins     TYPE mara-meins,
         icon      TYPE icon_d,      " 状态图标
         message   TYPE string,
       END OF ty_output.

* 内表和工作区定义
DATA: gt_material_data TYPE TABLE OF ty_material_info,
      gs_material_data TYPE ty_material_info,
      gt_output        TYPE TABLE OF ty_output,
      gs_output        TYPE ty_output.

* 全局变量
DATA: gv_error TYPE abap_bool,
      gv_msg   TYPE string.

* 范围表
DATA: r_matnr TYPE RANGE OF mara-matnr,
      r_werks TYPE RANGE OF mard-werks,
      r_lgort TYPE RANGE OF mard-lgort.

* ALV相关
DATA: go_alv     TYPE REF TO cl_salv_table,
      go_columns TYPE REF TO cl_salv_columns_table,
      go_column  TYPE REF TO cl_salv_column_table.


*选择屏幕 (ZMM_INVENTORY_REPORTSEL)
*&---------------------------------------------------------------------*
*& Include          ZMM_INVENTORY_REPORTSEL
*&---------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: s_matnr FOR mara-matnr  OBLIGATORY
                  MATCHCODE OBJECT mat1,  " 物料号
                 s_werks FOR mard-werks   " 工厂
                  MATCHCODE OBJECT h_t001w,
                 s_lgort FOR mard-lgort.  " 库存地点
  PARAMETERS:     p_allst AS CHECKBOX DEFAULT 'X'.  " 显示所有库存类型
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  PARAMETERS: p_layout TYPE slis_vari DEFAULT 'DEFAULT'.  " 布局
SELECTION-SCREEN END OF BLOCK b2.

*子程序 (ZMM_INVENTORY_REPORTF01)
*&---------------------------------------------------------------------*
*& Include          ZMM_INVENTORY_REPORTF01
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*&      Form  DATA_VALIDATION
*&---------------------------------------------------------------------*
*       数据验证
*----------------------------------------------------------------------*
FORM data_validation.
  
  " 检查选择条件是否为空
  IF s_matnr[] IS INITIAL.
    MESSAGE '请输入物料号' TYPE 'E'.
  ENDIF.
  
  " 转换选择条件到范围表
  r_matnr = s_matnr[].
  r_werks = s_werks[].
  r_lgort = s_lgort[].
  
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  GET_INVENTORY_DATA
*&---------------------------------------------------------------------*
*       获取库存数据
*----------------------------------------------------------------------*
FORM get_inventory_data.
  
  DATA: lt_mard TYPE TABLE OF mard.
  
  " 清理内表
  REFRESH: gt_material_data.
  
  " 获取库存地点数据
  SELECT matnr, werks, lgort, labst, umlme, insme, speme
    INTO TABLE lt_mard
    FROM mard
   WHERE matnr IN r_matnr
     AND werks IN r_werks
     AND lgort IN r_lgort.
  
  IF sy-subrc <> 0.
    gv_error = abap_true.
    gv_msg = '未找到库存数据'.
    RETURN.
  ENDIF.
  
  " 获取物料描述
  LOOP AT lt_mard INTO DATA(ls_mard).
    CLEAR gs_material_data.
    
    " 物料基本信息
    gs_material_data-matnr = ls_mard-matnr.
    gs_material_data-werks = ls_mard-werks.
    gs_material_data-lgort = ls_mard-lgort.
    gs_material_data-labst = ls_mard-labst.
    gs_material_data-umlme = ls_mard-umlme.
    gs_material_data-insme = ls_mard-insme.
    gs_material_data-speme = ls_mard-speme.
    
    " 计算总可用库存
    gs_material_data-total = ls_mard-labst.
    
    " 获取物料描述
    SELECT SINGLE maktx
      INTO gs_material_data-maktx
      FROM makt
     WHERE matnr = ls_mard-matnr
       AND spras = sy-langu.
       
    IF sy-subrc <> 0.
      gs_material_data-maktx = '描述不存在'.
    ENDIF.
    
    " 获取基本计量单位
    SELECT SINGLE meins
      INTO gs_material_data-meins
      FROM mara
     WHERE matnr = ls_mard-matnr.
    
    APPEND gs_material_data TO gt_material_data.
  ENDLOOP.
  
  " 按物料号排序
  SORT gt_material_data BY matnr werks lgort.
  
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  PROCESS_DATA
*&---------------------------------------------------------------------*
*       处理数据
*----------------------------------------------------------------------*
FORM process_data.
  
  DATA: lv_total_stock TYPE mard-labst.
  
  REFRESH: gt_output.
  
  LOOP AT gt_material_data INTO gs_material_data.
    CLEAR: gs_output, lv_total_stock.
    
    " 填充输出结构
    gs_output-matnr = gs_material_data-matnr.
    gs_output-maktx = gs_material_data-maktx.
    gs_output-werks = gs_material_data-werks.
    gs_output-lgort = gs_material_data-lgort.
    gs_output-labst = gs_material_data-labst.
    gs_output-umlme = gs_material_data-umlme.
    gs_output-insme = gs_material_data-insme.
    gs_output-speme = gs_material_data-speme.
    gs_output-meins = gs_material_data-meins.
    
    " 计算总库存
    lv_total_stock = gs_material_data-labst.
    
    IF p_allst = 'X'.
      lv_total_stock = lv_total_stock + gs_material_data-umlme.
    ENDIF.
    
    gs_output-total = lv_total_stock.
    
    " 获取工厂描述
    SELECT SINGLE name1
      INTO gs_output-werks_txt
      FROM t001w
     WHERE werks = gs_material_data-werks.
     
    IF sy-subrc <> 0.
      gs_output-werks_txt = ''.
    ENDIF.
    
    " 获取库存地点描述
    SELECT SINGLE lgobe
      INTO gs_output-lgort_txt
      FROM t001l
     WHERE werks = gs_material_data-werks
       AND lgort = gs_material_data-lgort.
       
    IF sy-subrc <> 0.
      gs_output-lgort_txt = ''.
    ENDIF.
    
    " 设置状态图标
    IF lv_total_stock = 0.
      gs_output-icon    = icon_red_light.
      gs_output-message = '库存不足'.
    ELSEIF lv_total_stock < 100.
      gs_output-icon    = icon_yellow_light.
      gs_output-message = '库存偏低'.
    ELSE.
      gs_output-icon    = icon_green_light.
      gs_output-message = '库存正常'.
    ENDIF.
    
    APPEND gs_output TO gt_output.
  ENDLOOP.
  
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DISPLAY_RESULTS
*&---------------------------------------------------------------------*
*       显示结果
*----------------------------------------------------------------------*
FORM display_results.
  
  IF gt_output IS INITIAL.
    MESSAGE '无数据显示' TYPE 'S'.
    RETURN.
  ENDIF.
  
  TRY.
      " 创建ALV对象
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_alv
        CHANGING
          t_table      = gt_output ).
      
      " 设置列属性
      go_columns = go_alv->get_columns( ).
      go_columns->set_optimize( abap_true ).
      
      " 设置列标题
      PERFORM set_column_titles.
      
      " 设置Zebra模式
      go_alv->get_display_settings( )->set_striped_pattern( abap_true ).
      
      " 显示ALV
      go_alv->display( ).
      
    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
  ENDTRY.
  
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  SET_COLUMN_TITLES
*&---------------------------------------------------------------------*
*       设置列标题
*----------------------------------------------------------------------*
FORM set_column_titles.
  
  DATA: lo_column TYPE REF TO cl_salv_column_table.
  
  TRY.
      " 物料号
      lo_column ?= go_columns->get_column( 'MATNR' ).
      lo_column->set_long_text( '物料号' ).
      lo_column->set_medium_text( '物料号' ).
      lo_column->set_short_text( '物料' ).
      
      " 物料描述
      lo_column ?= go_columns->get_column( 'MAKTX' ).
      lo_column->set_long_text( '物料描述' ).
      lo_column->set_medium_text( '描述' ).
      lo_column->set_short_text( '描述' ).
      
      " 工厂
      lo_column ?= go_columns->get_column( 'WERKS' ).
      lo_column->set_long_text( '工厂' ).
      
      " 工厂描述
      lo_column ?= go_columns->get_column( 'WERKS_TXT' ).
      lo_column->set_long_text( '工厂描述' ).
      lo_column->set_medium_text( '工厂描述' ).
      lo_column->set_short_text( '厂描述' ).
      
      " 库存地点
      lo_column ?= go_columns->get_column( 'LGORT' ).
      lo_column->set_long_text( '库存地点' ).
      lo_column->set_medium_text( '库位' ).
      lo_column->set_short_text( '库位' ).
      
      " 库存地点描述
      lo_column ?= go_columns->get_column( 'LGORT_TXT' ).
      lo_column->set_long_text( '库存地点描述' ).
      lo_column->set_medium_text( '库位描述' ).
      lo_column->set_short_text( '库描述' ).
      
      " 非限制库存
      lo_column ?= go_columns->get_column( 'LABST' ).
      lo_column->set_long_text( '非限制库存' ).
      lo_column->set_medium_text( '可用库存' ).
      lo_column->set_short_text( '可用' ).
      
      " 总库存
      lo_column ?= go_columns->get_column( 'TOTAL' ).
      lo_column->set_long_text( '总可用库存' ).
      lo_column->set_medium_text( '总库存' ).
      lo_column->set_short_text( '总库存' ).
      
      " 单位
      lo_column ?= go_columns->get_column( 'MEINS' ).
      lo_column->set_long_text( '单位' ).
      
      " 状态
      lo_column ?= go_columns->get_column( 'ICON' ).
      lo_column->set_long_text( '状态' ).
      
      " 消息
      lo_column ?= go_columns->get_column( 'MESSAGE' ).
      lo_column->set_long_text( '状态消息' ).
      lo_column->set_medium_text( '消息' ).
      
    CATCH cx_salv_not_found.
      " 忽略不存在的列
  ENDTRY.
  
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DOWNLOAD_TO_EXCEL
*&---------------------------------------------------------------------*
*       下载到Excel
*----------------------------------------------------------------------*
FORM download_to_excel.
  
  DATA: lt_rawdata TYPE truxs_t_text_data.
  
  " 调用函数下载数据
  CALL FUNCTION 'SAP_CONVERT_TO_XLS_FORMAT'
    EXPORTING
      i_filename        = '库存报表.xls'
    TABLES
      i_tab_sap_data    = gt_output
    EXCEPTIONS
      conversion_failed = 1
      OTHERS            = 2.
      
  IF sy-subrc = 0.
    MESSAGE '下载成功' TYPE 'S'.
  ELSE.
    MESSAGE '下载失败' TYPE 'E'.
  ENDIF.
  
ENDFORM.
