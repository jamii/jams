package main

import (
	_ "embed"
	"os"
	"text/template"
)

type Kind struct {
	Name      string
	ValueType string
	IsInt     bool
	SizeBits  uint
}

type Compression struct {
	Name string
}

type Data struct {
	Kinds        []Kind
	Compressions []Compression
}

//go:embed wsr_blocks.go.tmpl
var template_source string

func main() {
	data := Data{
		Kinds: []Kind{
			{
				Name:      "Uint8",
				ValueType: "uint8",
				IsInt:     true,
				SizeBits:  8,
			},
			{
				Name:      "Uint16",
				ValueType: "uint16",
				IsInt:     true,
				SizeBits:  16,
			},
			{
				Name:      "Uint32",
				ValueType: "uint32",
				IsInt:     true,
				SizeBits:  32,
			},
			{
				Name:      "Uint64",
				ValueType: "uint64",
				IsInt:     true,
				SizeBits:  64,
			},
			{
				Name:      "String",
				ValueType: "string",
				IsInt:     false,
				SizeBits:  0,
			},
		},
		Compressions: []Compression{
			{
				Name: "Dict",
			},
			{
				Name: "Size",
			},
			{
				Name: "Bias",
			},
		},
	}

	template, err := template.New("wsr_blocks").Parse(template_source)
	if err != nil {
		panic(err)
	}
	err = template.Execute(os.Stdout, data)
	if err != nil {
		panic(err)
	}
}
