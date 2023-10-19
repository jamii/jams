//go:build ignore

package main

import (
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

	path := "wsr_blocks_gen.go.tmpl"
	template, err := template.New(path).ParseFiles(path)
	if err != nil {
		panic(err)
	}

	file, err := os.Create("wsr_blocks_gen.go")
	if err != nil {
		panic(err)
	}
	defer file.Close()

	err = template.Execute(file, data)
	if err != nil {
		panic(err)
	}
}
