package heroku

import (
	"time"
)

// An app represents the program that you would like to deploy and run on
// Heroku.
type App struct {
	// when app was archived
	ArchivedAt time.Time `json:"archived_at"`

	// description from buildpack of app
	BuildpackProvidedDescription string `json:"buildpack_provided_description"`

	// when app was created
	CreatedAt time.Time `json:"created_at"`

	// git repo URL of app
	GitUrl string `json:"git_url"`

	// unique identifier of app
	Id string `json:"id"`

	// maintenance status of app
	Maintenance bool `json:"maintenance"`

	// unique name of app
	Name string `json:"name"`

	// identity of app owner
	Owner Account `json:"owner"`

	// identity of app region
	Region Region `json:"region"`

	// when app was released
	ReleasedAt time.Time `json:"released_at"`

	// git repo size in bytes of app
	RepoSize int `json:"repo_size"`

	// slug size in bytes of app
	SlugSize int `json:"slug_size"`

	// identity of app stack
	Stack Stack `json:"stack"`

	// when app was updated
	UpdatedAt time.Time `json:"updated_at"`

	// web URL of app
	WebUrl string `json:"web_url"`
}

// Create a new app.
//
// options is a struct of the optional parameters for this call: name, region,
// and stack.
func (c *Client) AppCreate(options AppCreateOpts) (*App, error) {
	var app App
	if err := c.Post(&app, "/apps", options); err != nil {
		return nil, err
	}
	return &app, nil
}

// AppCreateOpts holds the optional parameters for AppCreate
type AppCreateOpts struct {
	// name of app
	Name *string `json:"name,omitempty"`
	// identity of app region
	Region *string `json:"region,omitempty"`
	// identity of app stack
	Stack *string `json:"stack,omitempty"`
}

// Info for existing app.
//
// nameOrId is the unique name of app or unique identifier of app.
func (c *Client) AppInfo(nameOrId string) (*App, error) {
	var app App
	if err := c.Get(&app, "/apps/"+nameOrId); err != nil {
		return nil, err
	}
	return &app, nil
}

// Delete an existing app.
//
// nameOrId is the unique name of app or unique identifier of app.
func (c *Client) AppDelete(nameOrId string) error {
	return c.Delete("/apps/" + nameOrId)
}

// List existing apps.
//
// lr is an optional ListRange that sets the Range options for the paginated
// list of results.
func (c *Client) AppList(lr *ListRange) ([]App, error) {
	req, err := c.NewRequest("GET", "/apps", nil)
	if err != nil {
		return nil, err
	}

	if lr != nil {
		lr.SetHeader(req)
	}

	var apps []App
	return apps, c.DoReq(req, &apps)
}

// Update an existing app.
//
// nameOrId is the unique name of app or unique identifier of app.
//
// options is a struct of the optional parameters for this call: name and
// maintenance.
func (c *Client) AppUpdate(nameOrId string, options AppUpdateOpts) (*App, error) {
	var app App
	if err := c.Patch(&app, "/apps/"+nameOrId, options); err != nil {
		return nil, err
	}
	return &app, nil
}

// AppUpdateOpts holds the optional parameters for AppUpdate
type AppUpdateOpts struct {
	// maintenance status of app
	Maintenance *bool `json:"maintenance,omitempty"`
	// name of app
	Name *string `json:"name,omitempty"`
}
