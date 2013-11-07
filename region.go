package heroku

import (
	"time"
)

// A region represents a geographic location in which your application may run.
type Region struct {
	// when region was created
	CreatedAt time.Time `json:"created_at"`

	// description of region
	Description string `json:"description"`

	// unique identifier of region
	Id string `json:"id"`

	// unique name of region
	Name string `json:"name"`

	// when region was updated
	UpdatedAt time.Time `json:"updated_at"`
}
