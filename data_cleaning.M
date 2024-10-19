/*
    FIRST SPLIT THE DATA INTO 3 'SECTIONS'(REPRESENTING EACH KIND OF SUBCRIPTION TYPE) BY DUPLICATING THE ORIGINAL QUERY TWICE 
    THEN DO SOME TRANSFORMATIONS ON EACH QUERY:
    - REPLACE VALUES, REMOVE NULLS.
    - DELETE UNWANTED ROWS(TOTALS) AND COLUMNS.
    - UNPIVOT THE 8 NUMERICAL COLUMNS AND SPLIT THEM INTO 'QUARTER' AND 'YEAR'.
*/
let
    Source = Excel.Workbook(File.Contents("C:\Users\ricke\Downloads\Technical assessment Cohort 2.xlsx"), null, true),
    Dataset_Sheet = Source{[Item="Dataset",Kind="Sheet"]}[Data],
    #"Replaced Value" = Table.ReplaceValue(Dataset_Sheet,"(’000)","",Replacer.ReplaceText,{"Column1"}),
    #"Replaced Value1" = Table.ReplaceValue(#"Replaced Value","^ includes Wimax.","",Replacer.ReplaceText,{"Column1"}),
    #"Removed Blank Rows" = Table.SelectRows(#"Replaced Value1", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),
    #"Removed Columns" = Table.RemoveColumns(#"Removed Blank Rows",{"Column10"}),
    #"Removed Bottom Rows" = Table.RemoveLastN(#"Removed Columns",51),
    #"Fill Down" = Table.AddColumn(#"Removed Bottom Rows", "Column10", each #"Removed Bottom Rows"[Column1]{0}),
    #"Removed Top Rows" = Table.Skip(#"Fill Down",1),
    #"Promoted Headers" = Table.PromoteHeaders(#"Removed Top Rows", [PromoteAllScalars=true]),
    #"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"Country", type text}, {" 1Q 22", Int64.Type}, {"2Q 22", Int64.Type}, {"3Q 22", Int64.Type}, {"4Q 22", Int64.Type}, {"1Q 23", Int64.Type}, {"2Q 23", Int64.Type}, {"3Q 23", Int64.Type}, {"4Q 23", Int64.Type}, {"SUBSCRIBERS", type text}}),
    #"Index and Drop" = Table.SelectRows(Table.AddIndexColumn(#"Changed Type", "Index", 1, 1, Int64.Type), each not List.Contains({1, 8, 19}, [Index])),
    #"Removed Columns1" = Table.RemoveColumns(#"Index and Drop",{"Index"}),
    #"Unpivoted Only Selected Columns" = Table.Unpivot(#"Removed Columns1", {" 1Q 22", "2Q 22", "3Q 22", "4Q 22", "1Q 23", "2Q 23", "3Q 23", "4Q 23"}, "Attribute", "Value"),
    #"Split Column by Delimiter" = Table.SplitColumn(#"Unpivoted Only Selected Columns", "Attribute", Splitter.SplitTextByEachDelimiter({" "}, QuoteStyle.None, true), {"Attribute.1", "Attribute.2"}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Split Column by Delimiter",{{"Attribute.1", type text}, {"Attribute.2", Int64.Type}}),
    #"Added Prefix" = Table.TransformColumns(#"Changed Type1", {{"Attribute.2", each "20" & Text.From(_, "en-ZA"), type text}}),
    #"Renamed Columns" = Table.RenameColumns(#"Added Prefix",{{"SUBSCRIBERS", "Type of Subscriber"}, {"Attribute.1", "Quarter"}, {"Attribute.2", "Year"}, {"Value", "Subscribers"}})
in
    #"Renamed Columns"

/*
    HERE I APPENDED THE QUERIES BACK TOGETHER AND DID SOME MORE TRANSFORMING:
    - ENSURED ALL DATA AND DATATYPES ARE CORRECT AND CONSISTENT, RENAMED THE COLUMNS.
    - JOINED THE DATA TO ANOTHER QUERY(A DATASET I CREATED THAT MAPS EACH COUNTRY TO ITS
      REGION ACCORDING TO GEOGRAPHY AS THE ORIGINAL REGIONS WERE ICORRECTLY ASSIGNED) TO PULL IN 
      THE RESPECTIVE REGIONS AND COMPLETE THE DATASET.
*/
let
    Source = Table.Combine({MTN_DATA_1,MTN_DATA_2, MTN_DATA_3}),
    #"Capitalized Each Word" = Table.TransformColumns(Source,{{"Type of Subscriber", Text.Proper, type text}}),
    #"Filtered Rows" = Table.SelectRows(#"Capitalized Each Word", each true),
    #"Trimmed Text" = Table.TransformColumns(#"Filtered Rows",{{"Quarter", Text.Trim, type text}}),
    #"Replaced Value" = Table.ReplaceValue(#"Trimmed Text","–",0,Replacer.ReplaceValue,{"Subscribers"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Replaced Value",{{"Subscribers", Int64.Type}}),
    #"Reordered Columns" = Table.ReorderColumns(#"Changed Type",{"Type of Subscriber", "Country", "Quarter", "Year", "Subscribers"}),
    #"Replaced Value1" = Table.ReplaceValue(#"Reordered Columns","^","",Replacer.ReplaceText,{"Country"}),
    #"Merged Queries" = Table.NestedJoin(#"Replaced Value1", {"Country"}, Regions, {"country"}, "Regions", JoinKind.LeftOuter),
    #"Expanded Regions" = Table.ExpandTableColumn(#"Merged Queries", "Regions", {"region"}, {"Regions.region"}),
    #"Filtered Rows1" = Table.SelectRows(#"Expanded Regions", each true),
    #"Renamed Columns" = Table.RenameColumns(#"Filtered Rows1",{{"Regions.region", "Region"}}),
    #"Reordered Columns1" = Table.ReorderColumns(#"Renamed Columns",{"Region", "Type of Subscriber", "Country", "Quarter", "Year", "Subscribers"})
in
    #"Reordered Columns1"
