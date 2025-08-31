package waybar

import (
	"encoding/json"
	"os"
)

type Out struct {
	Text    string `json:"text,omitempty"`
	Tooltip string `json:"tooltip,omitempty"`
	Class   string `json:"class,omitempty"`
}

func Print(v any) error {
	enc := json.NewEncoder(os.Stdout)
	return enc.Encode(v)
}
